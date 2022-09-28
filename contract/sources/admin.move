module ferum::admin {
    use aptos_std::table;
    use std::signer::address_of;
    use std::string;
    use aptos_std::type_info;
    #[test_only]
    use ferum::coin_test_helpers;
    #[test_only]
    use aptos_framework::account;
    use ferum::fees::{Self, FeeStructure};
    use ferum_std::fixed_point_64;

    //
    // Errors
    //

    const ERR_NOT_ALLOWED: u64 = 0;
    const ERR_MARKET_NOT_EXISTS: u64 = 1;
    const ERR_MARKET_EXISTS: u64 = 2;

    //
    // Structs.
    //

    // Global info object for ferum.
    struct FerumInfo has key {
        // Map of all markets created, keyed by their instrument quote pairs.
        marketMap: table::Table<string::String, address>,
        // Default fee structure for all Ferum markets.
        feeStructure: FeeStructure,
    }

    // Key used to map to a market address. Is first converted to a string using TypeInfo.
    struct MarketKey<phantom I, phantom Q> has key {}

    //
    // Entry functions.
    //

    // All fee values are fixed points with 4 decimal places.
    public entry fun init_ferum(
        owner: &signer,
        defaultMakerFeeRaw: u128,
        defaultTakerFeeRaw: u128,
        defaultProtocolFeeRaw: u128,
        defaultLPFeeRaw: u128,
    ) {
        let ownerAddr = address_of(owner);
        assert!(!exists<FerumInfo>(ownerAddr), ERR_NOT_ALLOWED);
        assert!(ownerAddr == @ferum, ERR_NOT_ALLOWED);

        // Fees converted to fixed points.
        let defaultMakerFee = fixed_point_64::from_u128(defaultMakerFeeRaw, 4);
        let defaultTakerFee = fixed_point_64::from_u128(defaultTakerFeeRaw, 4);
        let defaultProtocolFee = fixed_point_64::from_u128(defaultProtocolFeeRaw, 4);
        let defaultLPFee = fixed_point_64::from_u128(defaultLPFeeRaw, 4);

        // Create fee structure.
        let feeStruct = fees::new_structure();
        fees::set_default_user_fees(&mut feeStruct, defaultTakerFee, defaultMakerFee);
        fees::set_default_protocol_fee(&mut feeStruct, defaultProtocolFee);
        fees::set_default_lp_fee(&mut feeStruct, defaultLPFee);

        move_to(owner, FerumInfo{
            marketMap: table::new<string::String, address>(),
            feeStructure: feeStruct,
        });
    }

    // Fee values are fixed points with 4 decimal places.
    public entry fun add_protocol_fee_tier(
        owner: &signer,
        minFerumTokenHoldings: u64,
        feeRaw: u128,
    ) acquires FerumInfo {
        let ownerAddr = address_of(owner);
        assert!(!exists<FerumInfo>(ownerAddr), ERR_NOT_ALLOWED);
        assert!(ownerAddr == @ferum, ERR_NOT_ALLOWED);

        let fee = fixed_point_64::from_u128(feeRaw, 4);
        let feeStruct = &mut borrow_global_mut<FerumInfo>(@ferum).feeStructure;
        fees::set_protocol_fee_tier(feeStruct, minFerumTokenHoldings, fee)
    }

    // Fee values are fixed points with 4 decimal places.
    public entry fun add_lp_fee_tier(
        owner: &signer,
        minFerumTokenHoldings: u64,
        feeRaw: u128,
    ) acquires FerumInfo {
        let ownerAddr = address_of(owner);
        assert!(!exists<FerumInfo>(ownerAddr), ERR_NOT_ALLOWED);
        assert!(ownerAddr == @ferum, ERR_NOT_ALLOWED);

        let fee = fixed_point_64::from_u128(feeRaw, 4);
        let feeStruct = &mut borrow_global_mut<FerumInfo>(@ferum).feeStructure;
        fees::set_lp_fee_tier(feeStruct, minFerumTokenHoldings, fee)
    }

    // Fee values are fixed points with 4 decimal places.
    public entry fun add_user_fee_tier(
        owner: &signer,
        minFerumTokenHoldings: u64,
        takerFeeRaw: u128,
        makerFeeRaw: u128,
    ) acquires FerumInfo {
        let ownerAddr = address_of(owner);
        assert!(!exists<FerumInfo>(ownerAddr), ERR_NOT_ALLOWED);
        assert!(ownerAddr == @ferum, ERR_NOT_ALLOWED);

        let takerFee = fixed_point_64::from_u128(takerFeeRaw, 4);
        let makerFee = fixed_point_64::from_u128(makerFeeRaw, 4);
        let feeStruct = &mut borrow_global_mut<FerumInfo>(@ferum).feeStructure;
        fees::set_user_fee_tier(feeStruct, minFerumTokenHoldings, takerFee, makerFee)
    }

    public entry fun remove_protocol_fee_tier(
        owner: &signer,
        minFerumTokenHoldings: u64,
    ) acquires FerumInfo {
        let ownerAddr = address_of(owner);
        assert!(!exists<FerumInfo>(ownerAddr), ERR_NOT_ALLOWED);
        assert!(ownerAddr == @ferum, ERR_NOT_ALLOWED);

        let feeStruct = &mut borrow_global_mut<FerumInfo>(@ferum).feeStructure;
        fees::remove_protocol_fee_tier(feeStruct, minFerumTokenHoldings)
    }

    public entry fun remove_lp_fee_tier(
        owner: &signer,
        minFerumTokenHoldings: u64,
    ) acquires FerumInfo {
        let ownerAddr = address_of(owner);
        assert!(!exists<FerumInfo>(ownerAddr), ERR_NOT_ALLOWED);
        assert!(ownerAddr == @ferum, ERR_NOT_ALLOWED);

        let feeStruct = &mut borrow_global_mut<FerumInfo>(@ferum).feeStructure;
        fees::remove_lp_fee_tier(feeStruct, minFerumTokenHoldings)
    }

    public entry fun remove_user_fee_tier(
        owner: &signer,
        minFerumTokenHoldings: u64,
    ) acquires FerumInfo {
        let ownerAddr = address_of(owner);
        assert!(!exists<FerumInfo>(ownerAddr), ERR_NOT_ALLOWED);
        assert!(ownerAddr == @ferum, ERR_NOT_ALLOWED);

        let feeStruct = &mut borrow_global_mut<FerumInfo>(@ferum).feeStructure;
        fees::remove_user_fee_tier(feeStruct, minFerumTokenHoldings)
    }

    //
    // Public functions.
    //

    public fun assert_ferum_inited() {
        assert!(exists<FerumInfo>(@ferum), ERR_NOT_ALLOWED);
    }

    public fun register_market<I, Q>(marketAddr: address) acquires FerumInfo {
        assert_ferum_inited();
        let info = borrow_global_mut<FerumInfo>(@ferum);
        let key = market_key<I, Q>();
        assert!(!table::contains(&info.marketMap, key), ERR_MARKET_EXISTS);
        table::add(&mut info.marketMap, market_key<I, Q>(), marketAddr);
    }

    public fun get_market_addr<I, Q>(): address acquires FerumInfo {
        assert_ferum_inited();
        let info = borrow_global<FerumInfo>(@ferum);
        let key = market_key<I, Q>();
        assert!(table::contains(&info.marketMap, key), ERR_MARKET_NOT_EXISTS);
        *table::borrow(&info.marketMap, key)
    }

    //
    // Private functions.
    //

    fun market_key<I, Q>(): string::String {
        type_info::type_name<MarketKey<I, Q>>()
    }

    //
    // Tests
    //

    #[test(owner = @ferum)]
    fun test_init_ferum(owner: &signer) {
        // Tests that an account can init ferum.

        init_ferum(owner, 0, 0, 0, 0);
    }

    #[test(owner = @0x1)]
    #[expected_failure]
    fun test_init_not_ferum(owner: &signer) {
        // Tests that an account that's not ferum can't init.

        init_ferum(owner, 0, 0, 0, 0);
    }

    #[test(owner = @ferum, other = @0x2)]
    fun test_register_market(owner: &signer, other: &signer) acquires FerumInfo {
        // Tests that a market can be registered.

        account::create_account_for_test(address_of(owner));
        account::create_account_for_test(address_of(other));
        init_ferum(owner, 0, 0, 0, 0);
        coin_test_helpers::setup_fake_coins(owner, other, 100, 18);
        register_market<coin_test_helpers::FMA, coin_test_helpers::FMB>(address_of(owner));
        let market_addr = get_market_addr<coin_test_helpers::FMA, coin_test_helpers::FMB>();
        assert!(market_addr == address_of(owner), 0);
    }

    #[test(owner = @ferum, other = @0x2)]
    #[expected_failure]
    fun test_register_other_combination(owner: &signer, other: &signer) acquires FerumInfo {
        // Tests that when market<I, Q> is registered, market<Q, I> is not.

        init_ferum(owner, 0, 0, 0, 0);
        coin_test_helpers::setup_fake_coins(owner, other, 100, 18);
        register_market<coin_test_helpers::FMA, coin_test_helpers::FMB>(address_of(owner));
        let market_addr = get_market_addr<coin_test_helpers::FMA, coin_test_helpers::FMB>();
        assert!(market_addr == address_of(owner), 0);
        get_market_addr<coin_test_helpers::FMB, coin_test_helpers::FMA>();
    }
}