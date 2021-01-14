const BigNumber = require('bignumber.js');

BigNumber.config({ EXPONENTIAL_AT: 1000 });

const _wad = new BigNumber('1000000000000000000');

const toWad = (...xs) => {
    let sum = new BigNumber(0);
    for (var x of xs) {
        sum = sum.plus(new BigNumber(x).times(_wad));
    }
    return sum.toFixed();
};

const fromWad = x => {
    return new BigNumber(x).div(_wad).toString();
};

const infinity = '999999999999999999999999999999999999999999';

const toBytes32 = s => {
    return web3.utils.fromAscii(s);
};

const fromBytes32 = b => {
    return web3.utils.toAscii(b);
};

function createEVMSnapshot() {
    const id = Date.now() + Math.floor(Math.random() * 100000000);
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: '2.0',
            method: 'evm_snapshot',
            params: [],
            id: id,
        }, (err, resp) => {
            if (err) {
                reject(err);
                return;
            }
            resolve(resp.result);
        });
    });
}

function restoreEVMSnapshot(snapshotId) {
    const id = Date.now() + Math.floor(Math.random() * 100000000);
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: '2.0',
            method: 'evm_revert',
            params: [snapshotId],
            id: id,
        }, (err, resp) => {
            if (err) {
                reject(err);
                return;
            }
            if (resp.result !== true) {
                reject(resp);
                return;
            }
            resolve();
        });
    });
}

function increaseEvmTime(duration) {
    const id = Date.now() + Math.floor(Math.random() * 100000000);
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: '2.0',
            method: 'evm_increaseTime',
            params: [duration],
            id: id,
        }, (err, resp) => {
            if (err) {
                reject(err);
                return;
            }
            web3.currentProvider.send({
                jsonrpc: '2.0',
                method: 'evm_mine',
                params: [],
                id: id + 1,
            }, (err, resp) => {
                if (err) {
                    reject(err);
                    return;
                }
                resolve();
            });
        });
    });
}

function increaseEvmBlock(_web3) {
    if (typeof _web3 === 'undefined') {
        _web3 = web3;
    }
    const id = Date.now() + Math.floor(Math.random() * 100000000);
    return new Promise((resolve, reject) => {
        _web3.currentProvider.send({
            jsonrpc: '2.0',
            method: 'evm_mine',
            params: [],
            id: id,
        }, (err, resp) => {
            if (err) {
                reject(err);
                return;
            }
            resolve();
        });
    });
}

function stopMiner() {
    const id = Date.now() + Math.floor(Math.random() * 100000000);
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: '2.0',
            method: 'miner_stop',
            params: [],
            id: id,
        }, (err, resp) => {
            if (err) {
                reject(err);
                return;
            }
            resolve();
        });
    });
}

function startMiner() {
    const id = Date.now() + Math.floor(Math.random() * 100000000);
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: '2.0',
            method: 'miner_start',
            params: [],
            id: id,
        }, (err, resp) => {
            if (err) {
                reject(err);
                return;
            }
            resolve();
        });
    });
}

module.exports = {
    infinity,
    toWad,
    fromWad,
    toBytes32,
    fromBytes32,
    createEVMSnapshot,
    restoreEVMSnapshot,
    increaseEvmTime,
    increaseEvmBlock,
    stopMiner,
    startMiner
};