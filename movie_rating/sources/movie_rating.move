module movie_rating::movie_rating{
    use sui::object::{Self, ID, UID};
    use sui::vec_map::{Self, VecMap};
    use sui::utf8::{Self, String};
    use std::option::{Self, Option};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::vector;
    use sui::event;

    // This module creates a shared movie database object where everyone can vote

    // This is made with sui 0.6.2

    // A shared object where movie objects are stored
    struct IMDB has key {
        id: UID,
        movie_db: VecMap<ID, Movie>, // The key is the id of the Movie
        admin_id: ID
    }

    // Only the admin has the authority to add movies
    // But anyone can add a rating
    struct MovieAdmin has key {
        id: UID
    }

    struct Movie has key, store {
        id: UID,
        movie_title: String,
        movie_synopsis: String,
        movie_director: String,
        movie_actors: vector<String>,
        movie_rating: Option<AverageRating>
    }

    struct AverageRating has store {
        for_movie: ID,
        average_rating: u64,
        people_voted: VecMap<address, Rating>,
        total_score: u64
    }


    struct  Rating has store {
        for_movie: ID,
        rating: u64,
        from: address
    }

    struct NewMovieAddedEvent has copy, drop{
        movie_id: ID,
        movie_title: String
    }

    struct NewRatingAddedEvent has copy, drop{
        for_movie: ID,
        rating: u64,
        from: address
    }

    // ##### CONSTANTS #####
    const MIN_RATING: u64 = 1;
    const MAX_RATING: u64 = 10;

    // ##### ERROR CODES #####
    const EYouAreNotAdmin: u64 = 500;
    const ERatingOutOfBounds: u64 = 501;
    const EMovieRatedBefore: u64 = 502;

    // ##### FUNCTIONS #####

    // create and share imdb and create and tranfer MovieAdmin capability to the publisher's address
    fun init(ctx: &mut TxContext){
        let admin_UID = object::new(ctx);

        transfer::share_object(IMDB{
            id: object::new(ctx),
            movie_db: vec_map::empty<ID, Movie>(),
            admin_id: *object::uid_as_inner(&admin_UID)
        });

        transfer::transfer(MovieAdmin{
            id: admin_UID,
        }, tx_context::sender(ctx));
    }

    // allows the admin to add Movies to Movie database
    public fun add_movie_to_db(
        cap: &MovieAdmin,
        db: &mut IMDB, 
        title: vector<u8>,
        synopsis: vector<u8>,
        director: vector<u8>,
        actors: vector<vector<u8>>,
        ctx: &mut TxContext
        ){
            assert!(&db.admin_id == object::borrow_id(cap), EYouAreNotAdmin);

            let movie_title = utf8::string_unsafe(title);
            let movie_synopsis = utf8::string_unsafe(synopsis);
            let movie_director = utf8::string_unsafe(director);
            let movie_actors = vector_u8_to_string(actors);

            let movie_UID = object::new(ctx);
            let movie_ID = *object::uid_as_inner(&movie_UID);

            vec_map::insert<ID, Movie>(
                &mut db.movie_db, 
                *&movie_ID, 
                Movie{
                    id: movie_UID,
                    movie_title: *&movie_title,
                    movie_synopsis,
                    movie_director,
                    movie_actors,
                    movie_rating: option::some(AverageRating{
                        for_movie: *&movie_ID,
                        average_rating: 0,
                        people_voted: vec_map::empty<address, Rating>(),
                        total_score: 0
                    })
            });

            event::emit(NewMovieAddedEvent{
                movie_id: movie_ID,
                movie_title
            });
        }

        public fun rate_movie(db: &mut IMDB, rating: u64, movie: ID, ctx: &mut TxContext){
            assert!((MIN_RATING <= rating) && (rating <= MAX_RATING), ERatingOutOfBounds);
            assert!(movie_rated_before(db, &movie, ctx), EMovieRatedBefore);

            let addr = tx_context::sender(ctx);

            add_rating(db, *&movie, Rating {
                for_movie: movie,
                rating: *&rating,
                from: *&addr
            }, ctx);

            event::emit(NewRatingAddedEvent{
                for_movie: movie,
                rating,
                from: addr
            })
        }

        public fun get_movie_average_rating(db: &mut IMDB, movie: ID, _ctx: &mut TxContext): u64 {
            let mov = get_movie_ref_from_db(&mut db.movie_db, &movie);
            let avg = get_average(mov);

            *&avg.average_rating
        }



        // ###### Helper Functions ######

        fun vector_u8_to_string(v: vector<vector<u8>>): vector<String>{
            let string_vec = vector::empty<String>();

            while (vector::length(&v) >= 1) {
                let vec = vector::pop_back<vector<u8>>(&mut v);
                let string = utf8::string_unsafe(vec);

                vector::push_back(&mut string_vec, string);
            };

            string_vec
        }

        // Checks if the movies has been rated before 
        fun movie_rated_before(db: &mut IMDB, movie_id: &ID, ctx: &mut TxContext): bool {
            let movie = get_movie_ref_from_db(&mut db.movie_db, movie_id);
            let average_rating = option::borrow<AverageRating>(&movie.movie_rating);
            
            vec_map::contains(&average_rating.people_voted, &tx_context::sender(ctx))
        }

        // Checks if this rating has been send from this address
        fun contains(rating: &Rating, from_address: &address): bool{
            &rating.from == from_address
        }

        // Gets a mut Movie reference from IMDB shared object's database
        fun get_movie_ref_from_db(db: &mut VecMap<ID,Movie>, movie_id: &ID): &mut Movie {
            vec_map::get_mut<ID,Movie>(db, movie_id)
        }

        // Get's a mut reference to the encapsulated average rating
        fun get_average(movie: &mut Movie): &mut AverageRating{
            option::borrow_mut(&mut movie.movie_rating)
        }


        // Add and update the Movie's rating
        fun add_rating(db: &mut IMDB, for_movie: ID, rating: Rating, ctx: &mut TxContext){
            let movie = get_movie_ref_from_db(&mut db.movie_db, &for_movie);

            let avg = get_average(movie);

            avg.total_score = avg.total_score + *&rating.rating;
            vec_map::insert<address, Rating>(&mut avg.people_voted, tx_context::sender(ctx), rating);

            avg.average_rating = *&avg.total_score / vec_map::size<address, Rating>(&avg.people_voted);
        }
}