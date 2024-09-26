#[allow(unused_use, unused_variable, unused_const, lint(self_transfer), unused_field)]
module ridewave::ride_wave {
    use sui::event;
    use sui::sui::SUI;
    use std::string::{String};
    use sui::coin::{Coin, value, split, put, take};
    use sui::object::new;
    use sui::balance::{Balance, zero, value as balance_value};
    use sui::tx_context::sender;
    use sui::table::{Self, Table};

    // Constants for error codes
    const Error_Invalid_Amount: u64 = 2;
    const Error_Insufficient_Payment: u64 = 4;
    const Error_Invalid_Price: u64 = 6;
    const Error_NoAvailableVehicles: u64 = 7;
    const Error_ServiceNotListed: u64 = 8;
    const Error_NotAuthorized: u64 = 0;
    const Error_Invalid_User: u64 = 10;

    // Enum for supported currencies
    public enum Currency has copy, drop, store {
        KSH,  // Kenyan Shilling
        USD,  // US Dollar
        SUI   // SUI token (native currency)
    }

    // User struct definition
    public struct User has key, store {
        id: UID,
        username: String,
        user_type: u8, // 0: passenger, 1: driver
        public_key: String
    }

    // Ride struct definition
    public struct Ride has key, store {
        id: UID,
        ride_id: ID,
        passengers: Table<address, bool>,
        driver: address,
        vehicle_details: String,
        price: u64,
        is_available: bool,
        balance: Balance<SUI>,
        currency: Currency, // Added currency field
    }

    public struct RideCap has key {
        id: UID,
        `for`: ID
    }

    // Ride Request struct
    public struct RideRequest has key {
        id: UID,
        ride_id: ID,
        passenger: address,
        status: u8, // 0: pending, 1: accepted, 2: completed, 3: canceled
    }

    // Driver Profile
    public struct DriverProfile has key {
        id: UID,
        driver: address,
        ratings: Table<address, u64>,
        driver_name: String,
        vehicle_info: String,
    }

    // Events
    public struct RideCreated has copy, drop {
        ride_id: ID,
        driver: address,
    }

    public struct RideRequested has copy, drop {
        ride_id: ID,
        passenger: address,
    }

    public struct RideAccepted has copy, drop {
        ride_id: ID,
        passenger: address,
    }

    public struct RideCompleted has copy, drop {
        ride_id: ID,
        passenger: address,
    }

    public struct FundsWithdrawn has copy, drop {
        amount: u64,
        recipient: address,
    }

    // Function to convert amounts to SUI based on currency
    public fun convert_to_sui(amount: u64, currency: &Currency): u64 {
        match (*currency) {
            Currency::KSH => amount / 100, // Example conversion
            Currency::USD => amount * 100,  // Example conversion
            Currency::SUI => amount,
        }
    }

    // Register user function
    public fun register_user(
        username: String,
        user_type: u8,
        public_key: String,
        ctx: &mut TxContext
    ) : User {
        User {
            id: new(ctx),
            username: username,
            user_type: user_type,
            public_key: public_key,
        }
    }

    // Function to create a new ride
    public fun create_ride(
        driver: address,
        vehicle_details: String,
        price: u64,
        currency: Currency, // Accept currency as parameter
        ctx: &mut TxContext
    ) {
        assert!(price > 0, Error_Invalid_Price);

        let ride_uid = new(ctx);
        let ride_id = object::uid_to_inner(&ride_uid);

        let ride = Ride {
            id: ride_uid,
            ride_id: ride_id,
            passengers: table::new(ctx),
            driver: driver,
            vehicle_details: vehicle_details,
            price: price,
            is_available: true,
            balance: zero<SUI>(),
            currency: currency, // Set currency for the ride
        };

        let cap = RideCap {
            id: new(ctx),
            `for`: ride_id,
        };

        transfer::transfer(cap, sender(ctx));
        transfer::share_object(ride);

        event::emit(RideCreated {
            ride_id: ride_id,
            driver: driver,
        });
    }

    // Function to request a ride
    public fun request_ride(
        ride: &mut Ride,
        ctx: &mut TxContext
    ) {
        assert!(ride.is_available, Error_NoAvailableVehicles);

        let passenger = ctx.sender();
        let ride_request_uid = new(ctx);
        ride.passengers.add(passenger, true);

        let request = RideRequest {
            id: ride_request_uid,
            ride_id: ride.ride_id,
            passenger: passenger,
            status: 0,
        };
        transfer::share_object(request);

        event::emit(RideRequested {
            ride_id: ride.ride_id,
            passenger: passenger,
        });
    }

    // Function to accept a ride request
    public fun accept_ride_request(
        ride: &mut Ride,
        request: &mut RideRequest,
        ctx: &mut TxContext
    ) {
        assert!(ride.is_available, Error_NoAvailableVehicles);
        assert!(request.status == 0, Error_ServiceNotListed);

        ride.is_available = false;
        request.status = 1;

        event::emit(RideAccepted {
            ride_id: ride.ride_id,
            passenger: request.passenger,
        });
    }

    // Function to complete a ride
    public fun complete_ride(
        ride: &mut Ride,
        request: &mut RideRequest,
        payment_coin: &mut Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(request.status == 1, Error_ServiceNotListed);
        assert!(payment_coin.value() >= ride.price, Error_Insufficient_Payment);

        let total_price = convert_to_sui(ride.price, &ride.currency); // Convert price to SUI
        let paid = split(payment_coin, total_price, ctx);
        put(&mut ride.balance, paid);
        request.status = 2;

        event::emit(RideCompleted {
            ride_id: ride.ride_id,
            passenger: request.passenger,
        });
    }

    // Function to withdraw funds from the ride balance
    public fun withdraw_funds(
        cap: &RideCap,
        ride: &mut Ride,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(object::id(ride) == cap.`for`, Error_NotAuthorized);
        let remaining = take(&mut ride.balance, amount, ctx);
        transfer::public_transfer(remaining, sender(ctx));

        event::emit(FundsWithdrawn {
            amount: amount,
            recipient: sender(ctx),
        });
    }

    // Function to create a driver profile
    public fun create_driver_profile(
        driver_name: String,
        vehicle_info: String,
        ctx: &mut TxContext
    ) {
        let driver_uid = new(ctx);
        let profile = DriverProfile {
            id: driver_uid,
            driver: ctx.sender(),
            ratings: table::new(ctx),
            driver_name: driver_name,
            vehicle_info: vehicle_info,
        };

        transfer::share_object(profile);
    }

    // Function to cancel a ride request
    public fun cancel_ride_request(
        ride: &mut Ride,
        request: &mut RideRequest,
        ctx: &mut TxContext
    ) {
        assert!(request.status == 0, Error_ServiceNotListed);  // Can only cancel pending requests

        ride.passengers.remove(request.passenger);
        request.status = 3;  // Mark request as canceled

        event::emit(RideRequested {
            ride_id: ride.ride_id,
            passenger: request.passenger,
        });
    }

    // Function to rate a driver after a ride is completed
    public fun rate_driver(
        profile: &mut DriverProfile,
        rating: u64,
        ctx: &mut TxContext
    ) {
        let passenger = ctx.sender();
        profile.ratings.add(passenger, rating);  // Add rating by passenger

        // Emit an event to log the rating
        event::emit(RideCompleted {
            ride_id: object::id(profile),
            passenger: passenger,
        });
    }

    // Struct to maintain a blacklist
    public struct Blacklist has key {
        id: UID,
        blacklisted_users: Table<address, bool>,
    }

    // Function to blacklist a user
    public fun add_to_blacklist(
        blacklist: &mut Blacklist,
        user: address,
        ctx: &mut TxContext
    ) {
        blacklist.blacklisted_users.add(user, true);
    }

    // Function to remove a user from the blacklist
    public fun remove_from_blacklist(
        blacklist: &mut Blacklist,
        user: address,
        ctx: &mut TxContext
    ) {
        blacklist.blacklisted_users.remove(user);
    }

    public fun dynamic_pricing(
        base_price: u64,
        demand_factor: u8,
        ride_availability: u64,
    ) : u64 {
        
        let surge_multiplier = (1 + (demand_factor as u64) / 10) * (1 + 100 / (ride_availability + 1));

        base_price * surge_multiplier
    }

    public fun predict_eta(
        distance: u64,
        traffic_factor: u8,
    ) : u64 {
        let base_eta = distance * 2;  // Assume 2 minutes per unit distance
        let traffic_delay = traffic_factor as u64 * 5;  // Traffic adds delay (5 mins per factor)
        base_eta + traffic_delay
    }

    public fun detect_fraud(
        ride_count: u64,
        last_week_ride_count: u64,
    ) : bool {
        (ride_count > last_week_ride_count * 2)  // Flag if rides doubled suddenly
    }

    // Function to copy the currency and convert amount
    public fun copy_currency(amount: u64, currency: &Currency): (u64, Currency) {
        let converted_amount = convert_to_sui(amount, currency);
        (converted_amount, *currency)  // Now valid with the copy ability
    }
}
