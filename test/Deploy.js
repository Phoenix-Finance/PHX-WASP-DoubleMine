const PoolProxy = artifacts.require('MinePoolProxy');
const MinePool = artifacts.require('MinePoolDelegate');
const MockTokenFactory = artifacts.require('TokenFactory');
const Token = artifacts.require("TokenMock");

const assert = require('chai').assert;
const Web3 = require('web3');
const config = require("../truffle.js");
const BN = require("bn.js");
var utils = require('./utils.js');

web3 = new Web3(new Web3.providers.HttpProvider("http://127.0.0.1:7545"));

// async function setupNetwork() {
//   let network = args.network;
//   web3url = "http://" + config.networks[network].host + ":" + config.networks[network].port;
//   console.log("setup network %s", network);
//   if (network == 'development' || network == 'soliditycoverage') {
//     web3 = new Web3(new Web3.providers.HttpProvider(web3url));
//   }
// }

/**************************************************
 test case only for the ganahce command
 ganache-cli --port=7545 --gasLimit=8000000 --accounts=10 --defaultBalanceEther=100000 --blockTime 1
 **************************************************/
contract('MinePoolProxy', function (accounts){
  let minepool;
  let proxy;
  let tokenFactory;
  let lpToken1;
  let lpToken2;
  let fnxToken;
  let time0;
  let time1;

  let stakeAmount = web3.utils.toWei('10', 'ether');
  let userLpAmount = web3.utils.toWei('1000', 'ether');
  let staker1 = accounts[1];
  let staker2 = accounts[2];
  let staker3 =  accounts[3];

  let fnxMineAmount = web3.utils.toWei('1000000', 'ether');
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

  before("init", async()=>{
    minepool = await MinePool.new();
    console.log("pool address:", minepool.address);

    proxy = await PoolProxy.new(minepool.address);
    console.log("proxy address:",proxy.address);

    tokenFactory = await MockTokenFactory.new();
    console.log("tokenfactory address:",tokenFactory.address);

    await tokenFactory.createToken(18);
    lpToken1 = await Token.at(await tokenFactory.createdToken());
    console.log("lptoken1 address:",lpToken1.address);

    await tokenFactory.createToken(18);
    fnxToken = await Token.at(await tokenFactory.createdToken());
    console.log("lptoken3 address:",fnxToken.address);

    //mock token set balance
    await lpToken1.adminSetBalance(staker1, userLpAmount);
    let staker1Balance =await lpToken1.balanceOf(staker1);
    //console.log(staker1Balance);
    assert.equal(staker1Balance,userLpAmount);

    await lpToken1.adminSetBalance(staker2, userLpAmount);
    await lpToken1.adminSetBalance(staker3, userLpAmount);
    await fnxToken.adminSetBalance(proxy.address,fnxMineAmount);

    //set mine coin info
    let res = await proxy.setPoolMineAddress(lpToken1.address,fnxToken.address);
    assert.equal(res.receipt.status,true);
  })

  it("[0020] stake test and check mined balance,should pass", async()=>{
    //set mine coin info
    let res = await proxy.setMineRate(disSpeed,interval,{from:accounts[0]});
    assert.equal(res.receipt.status,true);

    //set period finish second time
    time1 = await tokenFactory.getBlockTime();
    res = await proxy.setPeriodFinish(time1,time1+minutes,{from:accounts[0]});
//==============================================================================
    let preMinerBalance1 = await fnxToken.balanceOf(staker1);
    console.log("staker1 before mine balance = " + preMinerBalance1);

    let preMinerBalance2 = await fnxToken.balanceOf(staker2);
    console.log("staker 2 before mine balance = " + preMinerBalance2);

    let preMinerBalance3 = await fnxToken.balanceOf(staker3);
    console.log("staker 3 before mine balance = " + preMinerBalance3);

    res = await lpToken1.approve(proxy.address,stakeAmount,{from:staker1});
    res = await lpToken1.approve(proxy.address,stakeAmount,{from:staker2});
    res = await lpToken1.approve(proxy.address,stakeAmount,{from:staker3});

    //3 staker begin stake
    res = await proxy.stake(stakeAmount,"0x0",{from:staker1});
    assert.equal(res.receipt.status,true);
    res = await proxy.stake(stakeAmount,"0x0",{from:staker2});
    assert.equal(res.receipt.status,true);
    res = await proxy.stake(stakeAmount,"0x0",{from:staker3});
    assert.equal(res.receipt.status,true);

    let bigin = await web3.eth.getBlockNumber();
    console.log("start block="+ bigin)
    await utils.pause(web3,bigin + 60);

    totalPlan += web3.utils.fromWei(disSpeed)*60;
//==========================================================================
    //set period finish second time
    time0 = await tokenFactory.getBlockTime();
    res = await proxy.setMineRate(disSpeed2,interval2,{from:accounts[0]});
    assert.equal(res.receipt.status,true);

    res = await proxy.setPeriodFinish(time0,time0+30,{from:accounts[0]});
    assert.equal(res.receipt.status,true);

    //sleep for second time
    bigin = await web3.eth.getBlockNumber();
    console.log("start block="+ bigin)
    await utils.pause(web3,bigin + 30);

    totalPlan += web3.utils.fromWei(disSpeed2)*30;
//===========================================================================
    //set period finish third time
    time0 = await tokenFactory.getBlockTime();
    res = await proxy.setMineRate(disSpeed3,interval3,{from:accounts[0]});
    assert.equal(res.receipt.status,true);

    res = await proxy.setPeriodFinish(time0,time0+30,{from:accounts[0]});
    assert.equal(res.receipt.status,true);

    //sleep for third time
    bigin = await web3.eth.getBlockNumber();
    console.log("start block="+ bigin)
    await utils.pause(web3,bigin + 30);

    totalPlan += web3.utils.fromWei(disSpeed3)*30;
//=============================================================================

    //set period finish forth time
    time0 = await tokenFactory.getBlockTime();
    res = await proxy.setMineRate(disSpeed3,interval3,{from:accounts[0]});
    assert.equal(res.receipt.status,true);

    res = await proxy.setPeriodFinish(time0,time0+30,{from:accounts[0]});
    assert.equal(res.receipt.status,true);

    //sleep while for forth time
    bigin = await web3.eth.getBlockNumber();
    console.log("start block="+ bigin )
    await utils.pause(web3,bigin + 30);

    totalPlan += web3.utils.fromWei(disSpeed3)*30;

//==============================================================================

    let time2 = await tokenFactory.getBlockTime();
    let timeDiff = time2 - time1;
    console.log("timeDiff=" + timeDiff);

    res = await proxy.getReward({from:staker1});
    console.log(res.receipt.logs);
    assert.equal(res.receipt.status,true);

    res = await proxy.getReward({from:staker2});
    assert.equal(res.receipt.status,true);
    console.log(res.receipt.logs);

    res = await proxy.getReward({from:staker3});
    assert.equal(res.receipt.status,true);
    console.log(res.receipt.logs);

    let afterMinerBalance1= await fnxToken.balanceOf(staker1);
    console.log("after mine balance1 = " + afterMinerBalance1);
    let diff1 = web3.utils.fromWei(afterMinerBalance1) - web3.utils.fromWei(preMinerBalance1);
    console.log("diff1 = " + diff1);

    let afterMinerBalance2= await fnxToken.balanceOf(staker2);
    console.log("after mine balance2 = " + afterMinerBalance2);
    let diff2 = web3.utils.fromWei(afterMinerBalance2) - web3.utils.fromWei(preMinerBalance2);
    console.log("diff2 = " + diff2);

    let afterMinerBalance3= await fnxToken.balanceOf(staker3);
    time2 = await tokenFactory.getBlockTime();
    console.log("after mine balance3 = " + afterMinerBalance3);
    let diff3 = web3.utils.fromWei(afterMinerBalance3) - web3.utils.fromWei(preMinerBalance3);
    console.log("diff3 = " + diff3);

    let total = (diff1 + diff2 + diff3);
    console.log("got reward=" + total);
    console.log("plant reward=" + totalPlan);
    //assert.equal(total,true);
  })

})