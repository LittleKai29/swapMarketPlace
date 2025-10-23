module swapmarketplace::token_swap {
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};
    use sui::math;
    use sui::transfer;

    /// Struct lưu trữ thông tin pool
    public struct Pool<phantom A, phantom B> has key, store {
        id: UID,
        balance_a: Balance<A>,
        balance_b: Balance<B>,
        liquidity: Table<address, u64>, // Lưu trữ lượng thanh khoản của mỗi LP
    }

    /// Lỗi constants
    const EInsufficientBalance: u64 = 0;
    const EInvalidAmount: u64 = 1;
    const EPoolNotEmpty: u64 = 2;
    const EDivisionByZero: u64 = 3;

    /// Hàm thay thế cho mul_div: (a * b) / c
    fun mul_div(a: u64, b: u64, c: u64): u64 {
        assert!(c != 0, EDivisionByZero);
        let product = (a as u128) * (b as u128);
        ((product / (c as u128)) as u64)
    }

    /// Tạo pool mới
    public entry fun create_pool<A, B>(ctx: &mut TxContext) {
        let pool = Pool<A, B> {
            id: object::new(ctx),
            balance_a: balance::zero(),
            balance_b: balance::zero(),
            liquidity: table::new(ctx),
        };
        transfer::share_object(pool);
    }

    /// Thêm thanh khoản vào pool
    public entry fun add_liquidity<A, B>(
        pool: &mut Pool<A, B>,
        coin_a: Coin<A>,
        coin_b: Coin<B>,
        ctx: &mut TxContext
    ) {
        let amount_a = coin::value(&coin_a);
        let amount_b = coin::value(&coin_b);
        assert!(amount_a > 0 && amount_b > 0, EInvalidAmount);

        let (reserve_a, reserve_b) = (
            balance::value(&pool.balance_a),
            balance::value(&pool.balance_b)
        );

        if (reserve_a > 0 && reserve_b > 0) {
            assert!(
                mul_div(amount_a, reserve_b, reserve_a) == amount_b,
                EInvalidAmount
            );
        };

        balance::join(&mut pool.balance_a, coin::into_balance(coin_a));
        balance::join(&mut pool.balance_b, coin::into_balance(coin_b));

        let sender = tx_context::sender(ctx);
        // Sửa: Dùng u128 để tránh overflow khi nhân
        let product = (amount_a as u128) * (amount_b as u128);
        let liquidity_amount = math::sqrt((product as u64));
        let current_liquidity = if (table::contains(&pool.liquidity, sender)) {
            *table::borrow_mut(&mut pool.liquidity, sender)
        } else {
            0
        };
        table::add(&mut pool.liquidity, sender, current_liquidity + liquidity_amount);
    }

    /// Loại bỏ thanh khoản khỏi pool
    public entry fun remove_liquidity<A, B>(
        pool: &mut Pool<A, B>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let liquidity = *table::borrow(&pool.liquidity, sender);
        assert!(liquidity >= amount && amount > 0, EInvalidAmount);

        // Tính số token A và B trả lại dựa trên tỷ lệ
        let (reserve_a, reserve_b) = (
            balance::value(&pool.balance_a),
            balance::value(&pool.balance_b)
        );
        let total_liquidity = math::sqrt(reserve_a * reserve_b);
        let amount_a = mul_div(amount, reserve_a, total_liquidity);
        let amount_b = mul_div(amount, reserve_b, total_liquidity);

        // Cập nhật liquidity map
        table::add(&mut pool.liquidity, sender, liquidity - amount);

        // Trả token A và B cho người dùng
        let coin_a = coin::take(&mut pool.balance_a, amount_a, ctx);
        let coin_b = coin::take(&mut pool.balance_b, amount_b, ctx);
        transfer::public_transfer(coin_a, sender);
        transfer::public_transfer(coin_b, sender);
    }

    /// Swap A sang B
    public entry fun swap_a_to_b<A, B>(
        pool: &mut Pool<A, B>,
        coin_a: Coin<A>,
        min_amount_b: u64,
        ctx: &mut TxContext
    ) {
        let amount_a = coin::value(&coin_a);
        assert!(amount_a > 0, EInvalidAmount);

        let (reserve_a, reserve_b) = (
            balance::value(&pool.balance_a),
            balance::value(&pool.balance_b)
        );
        assert!(reserve_b > 0, EInsufficientBalance);

        // Tính lượng token B nhận được theo công thức x * y = k
        let amount_b = mul_div(amount_a, reserve_b, reserve_a + amount_a);
        assert!(amount_b >= min_amount_b, EInsufficientBalance);

        // Cập nhật số dư pool
        balance::join(&mut pool.balance_a, coin::into_balance(coin_a));
        let coin_b = coin::take(&mut pool.balance_b, amount_b, ctx);
        transfer::public_transfer(coin_b, tx_context::sender(ctx));
    }

    /// Swap B sang A
    public entry fun swap_b_to_a<A, B>(
        pool: &mut Pool<A, B>,
        coin_b: Coin<B>,
        min_amount_a: u64,
        ctx: &mut TxContext
    ) {
        let amount_b = coin::value(&coin_b);
        assert!(amount_b > 0, EInvalidAmount);

        let (reserve_a, reserve_b) = (
            balance::value(&pool.balance_a),
            balance::value(&pool.balance_b)
        );
        assert!(reserve_a > 0, EInsufficientBalance);

        // Tính lượng token A nhận được theo công thức x * y = k
        let amount_a = mul_div(amount_b, reserve_a, reserve_b + amount_b);
        assert!(amount_a >= min_amount_a, EInsufficientBalance);

        // Cập nhật số dư pool
        balance::join(&mut pool.balance_b, coin::into_balance(coin_b));
        let coin_a = coin::take(&mut pool.balance_a, amount_a, ctx);
        transfer::public_transfer(coin_a, tx_context::sender(ctx));
    }
}