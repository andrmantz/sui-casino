module casino::implements {
    use sui::tx_context::{Self, TxContext};
    use sui::bag::{Self, Bag};
    use sui::balance::{Self, Supply, Balance};
    use sui::coin::{Self, Coin};
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use std::ascii::String;
    use std::type_name::{get, into_string};
    use sui::vec_map::{Self, VecMap};
    
    friend casino::oracle;
    friend casino::admin;

    const MINUMUM_LIQUIDITY: u64 = 1_000;
    
    const ERR_ZERO_AMOUNT: u64 = 0;

    struct LP<phantom X> has drop, store {}

    struct Pool<phantom X> has store {
        casino_id: ID,
        reserves: Balance<X>,
        lp_supply: Supply<LP<X>>,
    }

    struct Casino has key {
        id: UID,
        is_paused: bool,
        oracle: address,
        pools: Bag,
        lucky_numbers: VecMap<u64, u64>
    }

    struct Ticket<phantom X> has key {
        id: UID,
        chosen_number: u64,
        epoch: u64,
        value: u64,
    }

    struct AdminCap has key {
        id: UID
    }
    

    fun init(ctx: &mut TxContext) {

        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));

        transfer::share_object(Casino {
            id: object::new(ctx),
            is_paused: false,
            oracle : @oracle,
            pools: bag::new(ctx),
            lucky_numbers: vec_map::empty(),
        });
    }

    /// Casino getters

    public fun oracle(casino: &mut Casino): address {
        casino.oracle
    }

    public fun casino_id(casino: &Casino): ID {
        object::uid_to_inner(&casino.id)    
    }

    public fun paused(casino: &mut Casino) : bool {
        casino.is_paused
    }

    public(friend) fun modify_admin(admincap: AdminCap, new_admin: address){
        transfer::transfer(admincap, new_admin);
    }

    public(friend) fun modify_oracle(casino: &mut Casino, new_oracle: address){
        casino.oracle = new_oracle;
    }
    

    public(friend) fun pause(casino: &mut Casino) {
        casino.is_paused = true
    }

    public(friend) fun unpause(casino: &mut Casino) {
        casino.is_paused = false
    }


    /// ======== LP related functions

    public(friend) fun get_mut_pool<X>(
        casino: &mut Casino,
    ): &mut Pool<X> {
        let lp_name = get_pool_name<X>();
        let exists = bag::contains_with_type<String, Pool<X>>(&casino.pools, lp_name);
        assert!(exists, 3);

        bag::borrow_mut<String, Pool<X>>(&mut casino.pools, lp_name)
    }

    public fun get_pool_name<X>(): String {
        into_string(get<X>())
    }

    public fun pool_exists<X>(casino: &Casino) : bool{
        let pool_name = get_pool_name<X>();
        bag::contains_with_type<String, Pool<X>>(&casino.pools, pool_name)

    }

    public(friend) fun create_pool<X>(casino: &mut Casino) {

        assert!(!pool_exists<X>(casino), 3);
        let pool_name = get_pool_name<X>();
        // assert!(!bag::contains_with_type<String, Pool<X>>(&casino.pools, pool_name), 3);

        let lp_supply = balance::create_supply(LP<X> {});
        let new_pool = Pool {
            casino_id: object::uid_to_inner(&casino.id),
            reserves: balance::zero<X>(),
            lp_supply: lp_supply
        };
        
        bag::add(&mut casino.pools, pool_name, new_pool);

    }


    public(friend) fun add_liquidity<X>(pool: &mut Pool<X>, coin_in: Coin<X>, out_min: u64, ctx: &mut TxContext): Coin<LP<X>> {
                let coin_value = coin::value(&coin_in);
                assert!(coin_value > 0, ERR_ZERO_AMOUNT);

                let (reserves, lp_supply) = get_reserves(pool);
                
                let liquidity_inserted = if (lp_supply == 0){
                    coin_value
                } else {
                    coin_value * lp_supply / reserves
                };

                assert!(liquidity_inserted > 0, 1);
                assert!(liquidity_inserted > out_min, 2);
                
                balance::join(&mut pool.reserves, coin::into_balance(coin_in));
                let balance = balance::increase_supply(&mut pool.lp_supply, liquidity_inserted);

                coin::from_balance(balance, ctx)

    }

    public(friend) fun remove_liquidity<X>(pool: &mut Pool<X>, lp_coin: Coin<LP<X>>, out_min: u64,ctx: &mut TxContext): Coin<X> {
                let lp_coin_value = coin::value(&lp_coin);
                assert!(lp_coin_value > 0, ERR_ZERO_AMOUNT);
                let (reserves, lp_supply) = get_reserves(pool);

                let coin_out = reserves * lp_coin_value / lp_supply;


                assert!(coin_out > 0, 1);
                assert!(coin_out > out_min, 2);
                
                balance::decrease_supply(&mut pool.lp_supply, coin::into_balance(lp_coin));
                coin::take(&mut pool.reserves, coin_out, ctx)

    }


    public fun get_reserves<X>(pool: &Pool<X>): (u64, u64) {
        (
            balance::value(&pool.reserves),
            balance::supply_value(&pool.lp_supply)
        )
    }


    // Casino-lottery related functions

    public(friend) fun create_bet<X>(pool: &mut Pool<X>, coin_in: Coin<X>, bet_number: u64, ctx: &mut TxContext): Ticket<X>{

        let coin_value = coin::value(&coin_in);
        assert!(coin_value > 0, ERR_ZERO_AMOUNT);
        balance::join(&mut pool.reserves, coin::into_balance(coin_in));
        
        Ticket {
            id: object::new(ctx),
            chosen_number: bet_number,
            epoch: tx_context::epoch(ctx),
            value: coin_value
        }
    }

    public(friend) fun redeem_bet<X>(casino: &mut Casino, ticket: Ticket<X>, ctx: &mut TxContext): Coin<X> {
        
        assert!(tx_context::epoch(ctx) > ticket.epoch, 55);
        let bet_winnings = winnings<X>(casino, ticket);
        let pool = get_mut_pool<X>(casino);


        coin::take(&mut pool.reserves, bet_winnings, ctx)

    }

    public fun winnings<X>(casino: &Casino, ticket: Ticket<X>): u64 {
        let Ticket {id, chosen_number, value, epoch} = ticket;

        object::delete(id);
        let lucky_number = vec_map::get<u64, u64>(&casino.lucky_numbers,  &epoch);

        get_multiplier(chosen_number, *lucky_number) * value
    }

    fun get_multiplier(chosen_number: u64, lucky_number: u64): u64 {
        let i = 0;
        while ( i < 7){
            if (chosen_number % 10 != lucky_number % 10)
                break;
            chosen_number = chosen_number / 10;
            lucky_number = lucky_number / 10;
            i = i + 1;
        };
        
        if (i == 7)
            return 100;
        if (i == 6)
            return 10;
        if (i == 5)
            return 5;
        if (i == 4)
            return 3;
        if (i == 3)
            return 1;
        0
    }


    /// Oracle function
    // Fail early pattern not followed
    public(friend) fun set_lucky_number(casino: &mut Casino, lucky_number: u64, epoch: u64) : bool {
        if (vec_map::contains<u64, u64>(&casino.lucky_numbers, &epoch))
            return false;
        
        vec_map::insert(&mut casino.lucky_numbers, epoch, lucky_number);
        true
    }


}