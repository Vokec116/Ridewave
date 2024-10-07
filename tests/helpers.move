#[test_only]
module ridewave::helpers {
    use sui::test_scenario::{Self as ts, next_tx, Scenario};
    use sui::test_utils::{assert_eq};
    use sui::coin::{Coin, mint_for_testing};
    use sui::clock::{Clock, Self};
    use sui::random::{Self, Random};

    const TEST_ADDRESS1: address = @0xee;

    public fun init_test_helper() : ts::Scenario{

       let mut scenario_val = ts::begin(TEST_ADDRESS1);
       let scenario = &mut scenario_val;
       
       scenario_val
    }

}