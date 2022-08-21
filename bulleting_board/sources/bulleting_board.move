module bulleting_board::bulleting_board {
    use sui::utf8::{Self, String};
    use sui::transfer;
    use sui::object::{Self, ID, UID};
    use sui::vec_map::{Self, VecMap};
    use sui::tx_context::{Self, TxContext};
    use std::option::{Self, Option};


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

    struct BulletingBoardAdmin has key{
        id: UID
    }

    struct BulletingNote has key, store{
        id: UID,
        note_title: String,
        note_body: String,
        referenced_item: Option<address>,
        note_author_id: ID
    }

    struct NotePostedEvent has copy, drop {
        note_author: address,
        note_id: ID,
        note_title: String,
    }

    struct AdminPostEvent has copy, drop {
        note_id: ID,
        note_title: String,
    }

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
}