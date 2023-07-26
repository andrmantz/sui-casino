module casino::interface {

    use sui::coin::Coin;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::ID;
    use sui::event::emit;

    use std::ascii::String;

    use casino::implements::{Self, Casino, LP, Ticket};

    const ERR_PAUSED: u64 = 100;
    const ERR_POOL_NOT_EXISTS: u64 = 101;


    struct LiquidityAdded has copy, drop {
        casino: ID,
        pool: String,
        amount: u64,
        sender: address,
    }

    struct LiquidityRemoved has copy, drop {
        casino: ID,
        pool: String,
        amount: u64,
        sender: address,
    }


    struct BetPlaced has copy, drop {
        casino: ID,
        pool: String,
        bet_amount: u64,
        bet_number: u64,
        epoch: u64,
        sender: address,
    }

    struct BetRedeemed has copy, drop {
        casino: ID,
        pool: String,
        ticket: ID,
        earned_amount: u64,
        sender: address,
    }

    struct BetCancelled has copy, drop {
        casino: ID,
        pool: String,
        ticket: ID,
        sender: address,
    }

    public entry fun add_liquidity<X>(
        casino: &mut Casino,
        coin_in: Coin<X>,
        lp_amount_out_min: u64,
        ctx: &mut TxContext
    ) {
        assert!(!implements::paused(casino), ERR_PAUSED);

        if (!implements::pool_exists<X>(casino)) {
            implements::create_pool<X>(casino);
        };
        let pool = implements::get_mut_pool<X>(casino);

        let (lp, lp_value) = implements::add_liquidity(
            pool,
            coin_in,
            lp_amount_out_min,
            ctx
        );


        transfer::public_transfer(
            lp,
            tx_context::sender(ctx)
        );

        let casino_id = implements::casino_id(casino);
        let pool = implements::get_pool_name<X>();

        emit(
            LiquidityAdded {
                casino: casino_id,
                pool,
                amount: lp_value,
                sender: tx_context::sender(ctx)
            }
        );
    }

    public entry fun remove_liquidity<X>(
        casino: &mut Casino,
        coin_in: Coin<LP<X>>,
        coin_out_min: u64,
        ctx: &mut TxContext
    ) {
        
        assert!(implements::pool_exists<X>(casino), ERR_POOL_NOT_EXISTS);
        let pool = implements::get_mut_pool<X>(casino);

        let (coin_out, coin_out_amount) = implements::remove_liquidity(
            pool,
            coin_in,
            coin_out_min,
            ctx
        );


        transfer::public_transfer(
            coin_out,
            tx_context::sender(ctx)
        );

        let casino_id = implements::casino_id(casino);
        let pool = implements::get_pool_name<X>();

        emit(
            LiquidityRemoved {
                casino: casino_id,
                pool,
                amount: coin_out_amount,
                sender: tx_context::sender(ctx)
            }
        );
    }

    public entry fun place_bet<X>(
        casino: &mut Casino,
        bet_coin: Coin<X>,
        bet_number: u64,
        ctx: &mut TxContext
    ) {
        assert!(!implements::paused(casino), ERR_PAUSED);
        assert!(implements::pool_exists<X>(casino), ERR_POOL_NOT_EXISTS);

        let pool = implements::get_mut_pool<X>(casino);

        let (ticket, bet_amount) = implements::create_bet(pool, bet_coin, bet_number, ctx);


        transfer::public_transfer(
            ticket,
            tx_context::sender(ctx)
        );

        let casino_id = implements::casino_id(casino);
        let pool = implements::get_pool_name<X>();

        emit(
            BetPlaced {
                casino: casino_id,
                pool,
                bet_amount,
                bet_number,
                epoch: tx_context::epoch(ctx),
                sender: tx_context::sender(ctx)
            }
        );
    }

    public entry fun redeem_bet<X>(
        casino: &mut Casino,
        ticket: Ticket<X>,
        ctx: &mut TxContext
    ) {
        assert!(!implements::paused(casino), ERR_PAUSED);

        let ticket_id = implements::ticket_id(&ticket);

        let (coin_out, coin_out_value) = implements::redeem_bet<X>(casino, ticket, ctx);


        transfer::public_transfer(
            coin_out,
            tx_context::sender(ctx)
        );

        let casino_id = implements::casino_id(casino);
        let pool = implements::get_pool_name<X>();

        emit(
            BetRedeemed {
                casino: casino_id,
                pool,
                ticket: ticket_id,
                earned_amount: coin_out_value,
                sender: tx_context::sender(ctx)
            }
        );
    }

    public entry fun cancel_bet<X>(
        casino: &mut Casino,
        ticket: Ticket<X>,
        ctx: &mut TxContext
    ) {
        assert!(!implements::paused(casino), ERR_PAUSED);

        let ticket_id = implements::ticket_id(&ticket);
        let (coin_out, _) = implements::cancel_bet<X>(casino, ticket, ctx);


        transfer::public_transfer(
            coin_out,
            tx_context::sender(ctx)
        );

        let casino_id = implements::casino_id(casino);
        let pool = implements::get_pool_name<X>();

        emit(
            BetCancelled {
                casino: casino_id,
                pool,
                ticket: ticket_id,
                sender: tx_context::sender(ctx)
            }
        );
    }
}