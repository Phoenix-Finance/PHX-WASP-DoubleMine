const PoolProxy = artifacts.require('FnxSushiFarmProxy');
const MinePool = artifacts.require('FnxSushiFarm');
const FNX = artifacts.require('FNXCoin');
const WETH = artifacts.require("USDCoin");
const UniswapV2Pair = artifacts.require("UniswapV2Pair");
const MasterChef = artifacts.require("MasterChef");

const assert = require('chai').assert;
const Web3 = require('web3');
const config = require("../truffle-config.js");
const BN = require("bn.js");
var utils = require('./utils.js');
web3 = new Web3(new Web3.providers.HttpProvider("http://127.0.0.1:7545"));

/**************************************************
 test case only for the ganahce command
 ganache-cli --port=7545 --gasLimit=8000000 --accounts=10 --defaultBalanceEther=100000 --blockTime 1
 **************************************************/
contract('MinePoolProxy', function (accounts){

  let stakeAmount = web3.utils.toWei('10', 'ether');
  let minePerday = web3.utils.toWei('10000', 'ether');
  let staker1 = accounts[1];
  let staker2 = accounts[2];
  let staker3 =  accounts[3];

  let fnxMineAmount = web3.utils.toWei('10000000', 'ether');
  let disSpeed = web3.utils.toWei('1', 'ether');
  let interval = 1;

  let disSpeed2 = web3.utils.toWei('2', 'ether');
  let interval2 = 1;

  let disSpeed3 = web3.utils.toWei('3', 'ether');
  let interval3 = 1;

  let minutes = 60;
  let hour    = 60*60;
  let day     = 24*hour;
  let totalPlan  = 0;
  let proxy;


  before("init", async()=>{
    minepool = await MinePool.new();
    console.log("pool address:", minepool.address);

    proxy = await PoolProxy.new(minepool.address);
    console.log("proxy address:",proxy.address);

    fnxinst = await FNX.new();
    console.log("fnxinst address:",fnxinst.address);

    sushiinst = await FNX.new();
    console.log("fnxinst address:",fnxinst.address);

    wethinst = await WETH.new();
    console.log("wethinst address:",wethinst.address);

    lpToken = await UniswapV2Pair.new();
    await lpToken.initialize(wethinst.address,fnxinst.address);

    chefinst = await MasterChef.new(
                              sushiinst.address,
                              accounts[1],
                              disSpeed,
                              0,
                              99999999);

    await chefinst.add(100,lpToken.address,true);

    await sushiinst.mint(accounts[0],fnxMineAmount);
    await fnxinst.mint(accounts[0],fnxMineAmount);
    await wethinst.mint(accounts[0],fnxMineAmount);
    await lpToken.mintlp(accounts[0],fnxMineAmount);

    await fnxinst.mint(accounts[1],fnxMineAmount);
    await wethinst.mint(accounts[1],fnxMineAmount);
    await lpToken.mintlp(accounts[1],fnxMineAmount);

    await proxy.setRewardToken(fnxinst.address);
   await fnxinst.mint(proxy.address,fnxMineAmount);

   res = await proxy.add(
                          lpToken.address,
                          0,
                          99999,
                          disSpeed2,
                          minePerday,
                          24*3600
                        );

    assert.equal(res.receipt.status,true);

    res = await proxy.setDoubleFarming(0,chefinst.address,0);
    assert.equal(res.receipt.status,true);

    res = await proxy.enableDoubleFarming(0,true);
    assert.equal(res.receipt.status,true);


///////////////////////////////////////////////////////////////////////////////////
    await lpToken.approve(proxy.address,stakeAmount);

    let blknum = await web3.eth.getBlockNumber();
    console.log("blocknum1=" + blknum)

    //form account[0]
    res = await proxy.deposit(0,stakeAmount,{from:accounts[0]});
    assert.equal(res.receipt.status,true);

    blknum = await web3.eth.getBlockNumber();
    console.log("blocknum2=" + blknum)

/////////////////////////////////////////////////////////////////////////////////
    console.log("deposit 1")
    await utils.pause(web3,blknum + 10);
    await lpToken.approve(proxy.address,stakeAmount,{from:accounts[1]});
    res = await proxy.deposit(0,stakeAmount,{from:accounts[1]});
    assert.equal(res.receipt.status,true);
/////////////////////////////////////////////////////////////////////////////////
    console.log("deposit 2")
    await utils.pause(web3,blknum + 10);
    await lpToken.approve(proxy.address,stakeAmount,{from:accounts[0]});
    res = await proxy.deposit(0,stakeAmount,{from:accounts[0]});
    assert.equal(res.receipt.status,true);


  })

  it("[0020] stake test and check mined balance,should pass", async()=>{
    let res = await proxy.totalStaked(0);
    console.log("totalstaked=" + res)
    let blknum =  await web3.eth.getBlockNumber();

    await utils.pause(web3,blknum + 1);

    console.log("blocknum3=" + blknum)

     res = await proxy.allPendingReward(0,accounts[0])
     console.log("pendingReward=",res[0].toString(),res[1].toString(),res[2].toString());

    res = await proxy._poolInfo(0)
    console.log("poolinf=",res[0].toString(),res[1].toString(),res[2].toString(),
    res[3].toString(),res[4].toString(),res[5].toString(),
    res[6].toString(),res[7].toString(),res[8].toString());

    res = await proxy.getMineInfo(0);
    console.log(res[0].toString(),
                res[1].toString(),
                res[2].toString(),
                res[3].toString())


  })


})