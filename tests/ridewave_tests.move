#[test_only]
module ridewave::ridewave {
    use sui::test_scenario::{Self as ts, next_tx};
    use sui::test_utils::{assert_eq};
    use sui::coin::{Coin, mint_for_testing};
    use sui::clock::{Clock, Self};
    use sui::sui::{SUI};

    use std::string::{Self};
    use std::debug::print;

    use ridewave::helpers::init_test_helper;
    use ridewave::ride_wave::{Self as rw, Currency, User, Ride, RideCap, RideRequest, DriverProfile};

    const TEST_ADDRESS1: address = @0xee;

    #[test]
    public fun test() {
        let mut scenario_test = init_test_helper();
        let scenario = &mut scenario_test;

      
        next_tx(scenario, TEST_ADDRESS1);
        {
            let username = string::utf8(b"mental");
            let user_type: u8 = 0;
            let public_key = string::utf8(b"key");

            let user = rw::register_user(username, user_type, public_key, ts::ctx(scenario));
            transfer::public_transfer(user, TEST_ADDRESS1);
       
        };

        ts::end(scenario_test);
    }

}