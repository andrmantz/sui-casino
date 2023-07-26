module casino::oracle {

    use sui::tx_context::{Self, TxContext};
    use sui::event::emit;
    use sui::object::ID;

    use casino::implements::{Self, Casino};
    
    const ERR_ONLY_ORACLE: u64 = 400;
    const ERR_PAUSED: u64 = 401;
    const ERR_ALREADY_SET: u64 = 402;
    const ERR_WRONG_NUMBER: u64 = 403;


    struct LuckyNumberSet has copy, drop {
        casino: ID,
        epoch: u64,
        lucky_number: u64,
    }

    public entry fun set_lucky_number(casino: &mut Casino, lucky_number: u64, ctx: &mut TxContext) {
        assert!(!implements::paused(casino), ERR_PAUSED);
        assert!(implements::oracle(casino) == tx_context::sender(ctx), ERR_ONLY_ORACLE);
        assert!(lucky_number < 10_000_000, ERR_WRONG_NUMBER);

        let previous_epoch = tx_context::epoch(ctx) - 1;

        assert!(implements::set_lucky_number(casino, lucky_number, previous_epoch), ERR_ALREADY_SET);

        emit(
            LuckyNumberSet {
                casino: implements::casino_id(casino),
                epoch: previous_epoch,
                lucky_number: lucky_number
            }
        );
    } 
}