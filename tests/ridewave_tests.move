#[test_only]
module ridewave::ridewave {
    use sui::test_scenario::{Self as ts, next_tx, ctx};
    use sui::test_utils::{assert_eq};
    use sui::coin::{Coin, mint_for_testing};
    use sui::clock::{Clock, Self};
    use sui::sui::{SUI};

    use std::string::{Self};
    use std::debug::print;

    use ridewave::helpers::init_test_helper;
    use ridewave::ride_wave::{Self as rw, Currency, User, Ride, RideCap, RideRequest, DriverProfile};

    const ADMIN: address = @0xe;
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

        next_tx(scenario, ADMIN);
        {
            let driver = TEST_ADDRESS1;
            let vehicle_details = string::utf8(b"mental");
            let price: u64 = 1_000_000_000;
            let currency = rw::get_ksh();

            rw::create_ride(driver, vehicle_details, price, currency, ts::ctx(scenario));
    
        };

        next_tx(scenario, TEST_ADDRESS1);
        {
            let mut ride = ts::take_shared<Ride>(scenario);

            rw::request_ride(&mut ride, ts::ctx(scenario));

            ts::return_shared(ride);    
        };

        next_tx(scenario, ADMIN);
        {
            let mut ride = ts::take_shared<Ride>(scenario);
            let cap = ts::take_from_sender<RideCap>(scenario);
            let mut request = ts::take_shared<RideRequest>(scenario);

            rw::accept_ride_request(&cap, &mut ride, &mut request, ts::ctx(scenario));

            ts::return_shared(ride);   
            ts::return_shared(request);   

            ts::return_to_sender(scenario, cap); 
        };

        next_tx(scenario, TEST_ADDRESS1);
        {
            let mut ride = ts::take_shared<Ride>(scenario);
            let mut request = ts::take_shared<RideRequest>(scenario);
            let payment_coin = mint_for_testing<SUI>(1_000_000_000, ts::ctx(scenario));

            rw::complete_ride(&mut ride, &mut request,  payment_coin, ts::ctx(scenario));

            ts::return_shared(ride);   
            ts::return_shared(request);   

        };

          next_tx(scenario, ADMIN);
        {
            let mut ride = ts::take_shared<Ride>(scenario);
            let cap = ts::take_from_sender<RideCap>(scenario);
            let amount = 1_000_000;
            
            rw::withdraw_funds(&cap, &mut ride, amount, ctx(scenario));

            ts::return_shared(ride);   
            ts::return_to_sender(scenario, cap); 

        };

        ts::end(scenario_test);
    }

}