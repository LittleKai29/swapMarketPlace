import { SuiClient, getFullnodeUrl } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';
import { getKeypairFromSuiWallet } from './wallet'; // Giả định bạn có hàm để lấy keypair từ ví SUI

// Thay thế các giá trị này bằng giá trị thực tế sau khi triển khai
const PACKAGE_ID = '0xYOUR_PACKAGE_ID'; // Địa chỉ package của hợp đồng
const POOL_ID = '0xYOUR_POOL_ID'; // Địa chỉ object của pool
const COIN_A_TYPE = '0xYOUR_COIN_A_TYPE'; // Loại token A
const COIN_B_TYPE = '0xYOUR_COIN_B_TYPE'; // Loại token B

export class SuiKit {
  private client: SuiClient;
  private keypair: Ed25519Keypair | null = null;

  constructor(client: SuiClient) {
    this.client = client;
  }

  async setKeypairFromWallet() {
    this.keypair = await getKeypairFromSuiWallet(); // Hàm giả định để lấy keypair từ ví
  }

  async createPool(): Promise<void> {
    const txb = new TransactionBlock();
    txb.moveCall({
      target: `${PACKAGE_ID}::token_swap::create_pool`,
      typeArguments: [COIN_A_TYPE, COIN_B_TYPE],
      arguments: [],
    });

    await this.executeTransaction(txb);
  }

  async addLiquidity(amountA: string, amountB: string): Promise<void> {
    const txb = new TransactionBlock();
    const coinA = txb.object(
      await this.client.getCoins({
        owner: this.keypair!.toSuiAddress(),
        coinType: COIN_A_TYPE,
      }).then((res) => res.data[0].coinObjectId)
    );
    const coinB = txb.object(
      await this.client.getCoins({
        owner: this.keypair!.toSuiAddress(),
        coinType: COIN_B_TYPE,
      }).then((res) => res.data[0].coinObjectId)
    );

    txb.moveCall({
      target: `${PACKAGE_ID}::token_swap::add_liquidity`,
      typeArguments: [COIN_A_TYPE, COIN_B_TYPE],
      arguments: [txb.object(POOL_ID), coinA, coinB],
    });

    await this.executeTransaction(txb);
  }

  async removeLiquidity(amount: string): Promise<void> {
    const txb = new TransactionBlock();
    txb.moveCall({
      target: `${PACKAGE_ID}::token_swap::remove_liquidity`,
      typeArguments: [COIN_A_TYPE, COIN_B_TYPE],
      arguments: [txb.object(POOL_ID), txb.pure.u64(amount)],
    });

    await this.executeTransaction(txb);
  }

  async swapAToB(amountA: string, minAmountB: string): Promise<void> {
    const txb = new TransactionBlock();
    const coinA = txb.object(
      await this.client.getCoins({
        owner: this.keypair!.toSuiAddress(),
        coinType: COIN_A_TYPE,
      }).then((res) => res.data[0].coinObjectId)
    );

    txb.moveCall({
      target: `${PACKAGE_ID}::token_swap::swap_a_to_b`,
      typeArguments: [COIN_A_TYPE, COIN_B_TYPE],
      arguments: [txb.object(POOL_ID), coinA, txb.pure.u64(minAmountB)],
    });

    await this.executeTransaction(txb);
  }

  async swapBToA(amountB: string, minAmountA: string): Promise<void> {
    const txb = new TransactionBlock();
    const coinB = txb.object(
      await this.client.getCoins({
        owner: this.keypair!.toSuiAddress(),
        coinType: COIN_B_TYPE,
      }).then((res) => res.data[0].coinObjectId)
    );

    txb.moveCall({
      target: `${PACKAGE_ID}::token_swap::swap_b_to_a`,
      typeArguments: [COIN_A_TYPE, COIN_B_TYPE],
      arguments: [txb.object(POOL_ID), coinB, txb.pure.u64(minAmountA)],
    });

    await this.executeTransaction(txb);
  }

  private async executeTransaction(txb: TransactionBlock): Promise<void> {
    if (!this.keypair) {
      throw new Error('Wallet not connected');
    }
    const result = await this.client.signAndExecuteTransactionBlock({
      transactionBlock: txb,
      signer: this.keypair,
      options: { showEffects: true },
    });
    if (result.effects?.status.status !== 'success') {
      throw new Error('Transaction failed');
    }
  }
}