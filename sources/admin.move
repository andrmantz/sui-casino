module casino::admin {

    use sui::event::emit;
    use sui::object::ID;

    use casino::implements::{Self, Casino, AdminCap};
    
    const ERR_ALREADY_PAUSED: u64 = 300;
    const ERR_NOT_PAUSED: u64 = 301;

    struct CasinoPaused has copy, drop {
        casino: ID,
    }

    struct CasinoUnpaused has copy, drop {
        casino: ID,
    }

    struct AdmincapTransferred has copy,drop {
        new_admin: address
    }

    struct OracleAddressModified has copy,drop {
        new_oracle: address
    }

    public entry fun pause(_: &AdminCap, casino: &mut Casino) {
        assert!(!implements::paused(casino), ERR_ALREADY_PAUSED);
        implements::pause(casino);

        emit(
            CasinoPaused { 
                casino: implements::casino_id(casino)
            }
        );
    }

    public entry fun unpause(_: &AdminCap, casino: &mut Casino){
        assert!(implements::paused(casino), ERR_NOT_PAUSED);
        implements::unpause(casino);
        emit(
            CasinoUnpaused { 
                casino: implements::casino_id(casino)
            }
        );
    }
    // @TODO pull over push pattern
    public entry fun modify_admin(adminCap: AdminCap, new_admin: address){
        implements::modify_admin(adminCap, new_admin);
        
        emit(
            AdmincapTransferred {
                new_admin
            }
        );
    }

    public entry fun modify_oracle(_: &AdminCap, casino: &mut Casino, new_oracle:address){
        implements::modify_oracle(casino, new_oracle);
        
        emit(
            OracleAddressModified {
                new_oracle
            }
        );
    }
}