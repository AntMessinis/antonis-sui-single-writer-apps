module bulleting_board::bulleting_board {
    use sui::utf8::{Self, String};
    use sui::transfer;
    use sui::object::{Self, ID, UID};
    use std::vector;
    use sui::vec_map::{Self, VecMap};
    use sui::tx_context::{Self, TxContext};
    use std::option::{Self, Option};
    use sui::event;

    // This module creates two bulleting boards
    // One where everyone is allowed to post notes 
    // And one where only an admin is allowed to post notes

    // This is made with sui 0.6.2

    // A shared bulleting board where anyone can post a note
    struct PublicBulletingBoard has key {
        id: UID,
        notes: VecMap<ID,BulletingNote>,
    }

    // A Bulleting board for very important announcements where only a cap has the authority to post but anyone can read
    struct AdminBulletingBoard has key {
        id: UID,
        notes: VecMap<ID,BulletingNote>,
        board_admin: ID
    }

    // Capability for the AdminBulletingBoard
    struct BulletingBoardAdmin has key{
        id: UID
    }

    // A bulleting note that has a title, a body, a possible reference to another object and an author
    struct BulletingNote has key, store{
        id: UID,
        note_title: String,
        note_body: String,
        referenced_item: Option<address>,
        note_author: address
    }

    // An event that announces that someone has posted a new note on public bulleting board
    struct NewNotePostedEvent has copy, drop {
        note_id: ID,
        note_title: String,
        note_author: address
    }

    // An event that announces that the admin has posted a new note
    struct NewAdminPostEvent has copy, drop {
        note_id: ID,
        note_title: String
    }

    // An event that announces that the current admin is transfering administrative rights
    struct TransferAdminOwnershipEvent has copy, drop {
        old_owner: address,
        new_owner: address
    }


    const MAX_TITLE_LENGTH: u64 = 100;
    const MAX_BODY_LENGTH : u64 = 1000;

    const MIN_TITLE_LENGTH : u64 = 10;
    const MIN_BODY_LENGTH : u64 = 25;

    const ENoteTitleNotBigEnough: u64 = 500;
    const ETitleBiggerThanExpected: u64 = 501;
    const ENoteBodyNotBigEnough: u64 = 502;
    const ENoteBodyBiggerThanExpected: u64 = 503;

    //On Module publish create and share the bulleting boards and crate and transfer the admin capability to the publisher
    fun init(ctx: &mut TxContext){
        let admin_uid = object::new(ctx);

        transfer::share_object(PublicBulletingBoard{
            id: object::new(ctx),
            notes: vec_map::empty<ID, BulletingNote>()
        });

        transfer::share_object(AdminBulletingBoard{
            id: object::new(ctx),
            notes: vec_map::empty<ID, BulletingNote>(),
            board_admin: *object::uid_as_inner(&admin_uid)
        });

        transfer::transfer(BulletingBoardAdmin{
            id: admin_uid
        }, tx_context::sender(ctx))
    }

    // Post a note withoute referencing another object
    public fun PostSimpleNote(
        board: &mut PublicBulletingBoard, 
        title: vector<u8>, 
        body: vector<u8>, 
        ctx: &mut TxContext
        ) {
            assert!(vector::length(&title) <= MAX_TITLE_LENGTH, ETitleBiggerThanExpected);
            assert!(vector::length(&title) >= MIN_TITLE_LENGTH, ENoteTitleNotBigEnough);
            assert!(vector::length(&body) <= MAX_BODY_LENGTH, ENoteBodyBiggerThanExpected);
            assert!(vector::length(&body) >= MIN_BODY_LENGTH, ENoteBodyNotBigEnough);

            let uid = object::new(ctx);
            let id = *object::uid_as_inner(&uid);
            let author = tx_context::sender(ctx);
            let title = utf8::string_unsafe(title);

            // Add note to public Bulleting Board
            vec_map::insert(
                &mut board.notes, 
                *&id,
                BulletingNote{
                    id: uid,
                    note_title: *&title,
                    note_body: utf8::string_unsafe(body),
                    referenced_item: option::none<address>(),
                    note_author: *&author
                });

            // Announce to everyone that you have posted a Note
            event::emit(NewNotePostedEvent{
                note_author: author,
                note_id: id,
                note_title: title
            })
        }

    // Post a note that references an other object
    public fun PostNoteWithRef(
        board: &mut PublicBulletingBoard, 
        title: vector<u8>, 
        body: vector<u8>, 
        ref_address: address,
        ctx: &mut TxContext
    ){
        assert!(vector::length(&title) <= MAX_TITLE_LENGTH, ETitleBiggerThanExpected);
        assert!(vector::length(&title) >= MIN_TITLE_LENGTH, ENoteTitleNotBigEnough);
        assert!(vector::length(&body) <= MAX_BODY_LENGTH, ENoteBodyBiggerThanExpected);
        assert!(vector::length(&body) >= MIN_BODY_LENGTH, ENoteBodyNotBigEnough);

        let uid = object::new(ctx);
        let id = *object::uid_as_inner(&uid);
        let author = tx_context::sender(ctx);
        let title = utf8::string_unsafe(title);

        // Add note to public Bulleting Board
        vec_map::insert(
            &mut board.notes, 
            *&id,
            BulletingNote{
                id: uid,
                note_title: *&title,
                note_body: utf8::string_unsafe(body),
                referenced_item: option::some<address>(ref_address),
                note_author: *&author    
            });

        // Announce to everyone that you have posted a Note
        event::emit(NewNotePostedEvent{
            note_author: author,
            note_id: id,
            note_title: title
        });
    }

    public fun postSimpleNoteToAdminBoard(
        _: &mut BulletingBoardAdmin,
        board: &mut AdminBulletingBoard, 
        title: vector<u8>, 
        body: vector<u8>, 
        ctx: &mut TxContext
    ){
        assert!(vector::length(&title) <= MAX_TITLE_LENGTH, ETitleBiggerThanExpected);
        assert!(vector::length(&title) >= MIN_TITLE_LENGTH, ENoteTitleNotBigEnough);
        assert!(vector::length(&body) <= MAX_BODY_LENGTH, ENoteBodyBiggerThanExpected);
        assert!(vector::length(&body) >= MIN_BODY_LENGTH, ENoteBodyNotBigEnough);
        
        let uid = object::new(ctx);
        let id = *object::uid_as_inner(&uid);
        let author = tx_context::sender(ctx);
        let title = utf8::string_unsafe(title);

        vec_map::insert(
            &mut board.notes, 
            *&id,
            BulletingNote{
                id: uid,
                note_title: *&title,
                note_body: utf8::string_unsafe(body),
                referenced_item: option::none<address>(),
                note_author: *&author    
            });

            event::emit(NewAdminPostEvent{
                note_id: id,
                note_title: title
            });
    }


    public fun postNoteWithRefToAdminBoard(
        _: &mut BulletingBoardAdmin,
        board: &mut AdminBulletingBoard, 
        title: vector<u8>, 
        body: vector<u8>,
        ref_address: address,
        ctx: &mut TxContext
    ){
        assert!(vector::length(&title) <= MAX_TITLE_LENGTH, ETitleBiggerThanExpected);
        assert!(vector::length(&title) >= MIN_TITLE_LENGTH, ENoteTitleNotBigEnough);
        assert!(vector::length(&body) <= MAX_BODY_LENGTH, ENoteBodyBiggerThanExpected);
        assert!(vector::length(&body) >= MIN_BODY_LENGTH, ENoteBodyNotBigEnough);
        
        let uid = object::new(ctx);
        let id = *object::uid_as_inner(&uid);
        let author = tx_context::sender(ctx);
        let title = utf8::string_unsafe(title);

        vec_map::insert(
            &mut board.notes, 
            *&id,
            BulletingNote{
                id: uid,
                note_title: *&title,
                note_body: utf8::string_unsafe(body),
                referenced_item: option::some<address>(ref_address),
                note_author: *&author    
            });

            event::emit(NewAdminPostEvent{
                note_id: id,
                note_title: title
            });
    }

    public fun readNoteFromBulletingBoard(
        board: &mut PublicBulletingBoard, 
        note_id: &ID, 
        _ctx: &mut TxContext
        ): (&String, &String, &address, &address){

        let note_ref = vec_map::get<ID, BulletingNote>(&mut board.notes, note_id);

        (&note_ref.note_title, &note_ref.note_body, option::borrow(&note_ref.referenced_item) , &note_ref.note_author)
    }

    public fun readNoteFromAdminBulletingBoard(
        board: &mut AdminBulletingBoard,
        note_id: &ID,
        _ctx: &mut TxContext
    ): (&String, &String, &address, &address){

        let note_ref = vec_map::get<ID, BulletingNote>(&mut board.notes, note_id);

        (&note_ref.note_title, &note_ref.note_body, option::borrow(&note_ref.referenced_item) , &note_ref.note_author)
    }


    // Transfer the administrative rights of AdminBulletingBoard and announce it so everyone knows who the next owner is
    public fun transferAdminRights(cap: BulletingBoardAdmin, next_owner: address ,ctx: &mut TxContext){
        transfer::transfer(cap, *&next_owner);

        event::emit(TransferAdminOwnershipEvent{
            old_owner: tx_context::sender(ctx),
            new_owner: next_owner
        })
    }

}