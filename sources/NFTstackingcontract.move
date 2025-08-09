module bhanu_addr::NFTStaking {
    use aptos_framework::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;

    /// Struct representing an NFT staking pool
    struct StakingPool has store, key {
        total_staked_nfts: u64,     // Total number of NFTs staked
        reward_rate: u64,           // Reward tokens per second per NFT
        total_rewards_pool: u64,    // Total rewards available in the pool
    }

    /// Struct representing a user's staking position
    struct StakerInfo has store, key {
        staked_nfts: u64,          // Number of NFTs staked by user
        last_reward_time: u64,     // Last time rewards were calculated
        pending_rewards: u64,      // Accumulated rewards not yet claimed
    }

    /// Function to initialize the staking pool
    public fun initialize_staking_pool(
        owner: &signer, 
        reward_rate: u64, 
        initial_rewards: u64
    ) {
        let staking_pool = StakingPool {
            total_staked_nfts: 0,
            reward_rate,
            total_rewards_pool: initial_rewards,
        };
        
        let staker_info = StakerInfo {
            staked_nfts: 0,
            last_reward_time: timestamp::now_seconds(),
            pending_rewards: 0,
        };

        // Deposit initial rewards into the pool
        let initial_deposit = coin::withdraw<AptosCoin>(owner, initial_rewards);
        coin::deposit<AptosCoin>(signer::address_of(owner), initial_deposit);

        move_to(owner, staking_pool);
        move_to(owner, staker_info);
    }

    /// Function to stake NFTs
    public fun stake_nfts(
        user: &signer, 
        pool_owner: address, 
        nft_count: u64
    ) acquires StakingPool, StakerInfo {
        let user_addr = signer::address_of(user);
        let current_time = timestamp::now_seconds();
        
        // Update staking pool
        let pool = borrow_global_mut<StakingPool>(pool_owner);
        pool.total_staked_nfts = pool.total_staked_nfts + nft_count;

        // Update or create staker info
        if (exists<StakerInfo>(user_addr)) {
            let staker = borrow_global_mut<StakerInfo>(user_addr);
            let time_elapsed = current_time - staker.last_reward_time;
            let earned_rewards = staker.staked_nfts * pool.reward_rate * time_elapsed;
            
            staker.pending_rewards = staker.pending_rewards + earned_rewards;
            staker.staked_nfts = staker.staked_nfts + nft_count;
            staker.last_reward_time = current_time;
        } else {
            let new_staker = StakerInfo {
                staked_nfts: nft_count,
                last_reward_time: current_time,
                pending_rewards: 0,
            };
            move_to(user, new_staker);
        };
    }

    /// Function to claim accumulated rewards
    public fun claim_rewards(
        user: &signer,
        pool_owner: &signer
    ) acquires StakingPool, StakerInfo {
        let user_addr = signer::address_of(user);
        let pool_owner_addr = signer::address_of(pool_owner);
        let current_time = timestamp::now_seconds();

        let pool = borrow_global_mut<StakingPool>(pool_owner_addr);
        let staker = borrow_global_mut<StakerInfo>(user_addr);
        
        // Calculate latest rewards
        let time_elapsed = current_time - staker.last_reward_time;
        let earned_rewards = staker.staked_nfts * pool.reward_rate * time_elapsed;
        let total_rewards = staker.pending_rewards + earned_rewards;

        // Transfer rewards from pool owner to user
        if (total_rewards > 0) {
            let reward_coins = coin::withdraw<AptosCoin>(pool_owner, total_rewards);
            coin::deposit<AptosCoin>(user_addr, reward_coins);
            
            pool.total_rewards_pool = pool.total_rewards_pool - total_rewards;
            staker.pending_rewards = 0;
            staker.last_reward_time = current_time;
        };
    }
}