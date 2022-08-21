module bulleting_board::bulleting_board {
    use sui::utf8::{Self, String};
    use sui::transfer;
    use sui::object::{Self, ID, UID};
    use std::vector;
    use sui::vec_map::{Self, VecMap};
    use sui::tx_context::{Self, TxContext};
    use std::option::{Self, Option};
    use sui::event;


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

    struct BulletingNote has key, store{
        id: UID,
        note_title: String,
        note_body: String,
        referenced_item: Option<address>,
        note_author: address
    }

    struct NotePostedEvent has copy, drop {
        note_title: String,
        note_id: ID,
        note_author: address,
    }

    struct AdminPostEvent has copy, drop {
        note_id: ID,
        note_title: String
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
            event::emit(NotePostedEvent{
                note_author: author,
                note_id: id,
                note_title: title
            })
        }

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
        event::emit(NotePostedEvent{
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

            event::emit(AdminPostEvent{
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

            event::emit(AdminPostEvent{
                note_id: id,
                note_title: title
            });
    }

}