const { time, expectEvent} = require("@openzeppelin/test-helpers");
const PoolProxy = artifacts.require('PhxDoubleFarmProxy');
const MinePool = artifacts.require('PhxDoubleFarm');
const LpToken = artifacts.require('WaspToken');
const WaspToken = artifacts.require('WaspToken');
const CphxToken = artifacts.require("WaspToken");
const Chef = artifacts.require("WanSwapFarm");
const MultiSignature = artifacts.require("multiSignature");

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
  let rewardOneDay = web3.utils.toWei('5000', 'ether');
  let blockSeed = 5;
  let bocksPerDay = 3600*24/blockSeed;
  let rewardPerBlock = new BN(rewardOneDay).div(new BN(bocksPerDay));
  console.log(rewardPerBlock.toString(10));

  let farmPoolAmount = web3.utils.toWei("10000000","ether");
  let stakeAmount = web3.utils.toWei('10', 'ether');
  let minePerday = web3.utils.toWei('10000', 'ether');
  let startBlock = 0;

  let staker1 = accounts[2];
  let staker2 = accounts[3];

  let operator0 = accounts[0];
  let operator1 = accounts[1]

  let phxMineAmount = web3.utils.toWei('10000000', 'ether');
  let phxAccountAmount = web3.utils.toWei('10000000', 'ether');
  let disSpeed1 = web3.utils.toWei('1', 'ether');
  let interval = 1;

  let disSpeed2 = web3.utils.toWei('2', 'ether');
  let interval2 = 1;

  let disSpeed3 = web3.utils.toWei('3', 'ether');
  let interval3 = 1;

  let minutes = 60;
  let hour    = 60*60;
  let day     = 24*hour;
  let totalPlan  = 0;

  let phxfarmproxyinst;
  let phxfarminst;
  let wanfarminst;

  let lp;
  let wasp
  let cphx;
  let mulSiginst;
  let startTime;

  before("init", async()=>{

    lp = await LpToken.new("lptoken",18);
    wasp = await WaspToken.new("wasp",18);
    cphx = await CphxToken.new("cphx",18);

    await lp.mint(staker1,phxAccountAmount);
    await lp.mint(staker2,phxAccountAmount);

    //setup wanfarm
    wanfarminst = await Chef.new(wasp.address,accounts[0],disSpeed1);
    await wasp.mint(wanfarminst.address,farmPoolAmount);
    await wanfarminst.add(100,lp.address,true);

    //setup multisig
    let addresses = [accounts[7],accounts[8],accounts[9]]
    mulSiginst = await MultiSignature.new(addresses,2,{from : accounts[0]})

    //set phxfarm
    phxfarminst = await MinePool.new(mulSiginst.address);
    console.log("pool address:", phxfarminst.address);

    phxfarmproxyinst = await PoolProxy.new(phxfarminst.address,cphx.address,mulSiginst.address);
    console.log("proxy address:",phxfarmproxyinst.address);
    await cphx.mint(phxfarmproxyinst.address,farmPoolAmount);

    //set operator 0
    await phxfarmproxyinst.setOperator(0,operator0);
    await phxfarmproxyinst.setOperator(1,operator1);

    phxfarmproxyinst = await MinePool.at(phxfarmproxyinst.address);
    console.log("proxy address:" + phxfarmproxyinst.address);

    //ser reward token
  //  await phxfarmproxyinst.setRewardToken(cphx.address);
    let block = await web3.eth.getBlock("latest");
    startTime = block.timestamp + 1000;
    console.log("set block time",startTime);

    let endBlock = block.number + bocksPerDay*365;

    res = await phxfarmproxyinst.add(lp.address,
                          startTime,
                          endBlock,
                          disSpeed1,
                          minePerday,
                          24*3600,
                          5,{from:operator1});
    assert.equal(res.receipt.status,true);

    res = await phxfarmproxyinst.setDoubleFarming(0,wanfarminst.address,0,{from:operator1});
    assert.equal(res.receipt.status,true);

    res = await phxfarmproxyinst.enableDoubleFarming(0,true,{from:operator1});
    assert.equal(res.receipt.status,true);
    console.log("setting end")
  })

  it("[0010] stake in,should pass", async()=>{
    ////////////////////////staker1///////////////////////////////////////////////////////////
    res = await lp.approve(phxfarmproxyinst.address,stakeAmount,{from:staker1});
    assert.equal(res.receipt.status,true);
    time.increaseTo(startTime+1);


    res = await phxfarmproxyinst.deposit(0,stakeAmount,{from:staker1});
    assert.equal(res.receipt.status,true);

    let mineInfo = await phxfarmproxyinst.getMineInfo(0);
    console.log(mineInfo[0].toString(10),mineInfo[1].toString(10),
                mineInfo[2].toString(10),mineInfo[3].toString(10));
/////////////////////////////////////////////////////////////////////////////////
    time.increaseTo(startTime+1000);
    await lp.approve(phxfarmproxyinst.address,stakeAmount,{from:staker2});
    res = await phxfarmproxyinst.deposit(0,stakeAmount,{from:staker2});
    assert.equal(res.receipt.status,true);

    mineInfo = await phxfarmproxyinst.getMineInfo(0);
    console.log(mineInfo[0].toString(10),mineInfo[1].toString(10),
                mineInfo[2].toString(10),mineInfo[3].toString(10));

    let block = await web3.eth.getBlock(mineInfo[2]);
    console.log("start block time",block.timestamp);

  })

  it("[0020] check staker1 mined balance,should pass", async()=>{
     time.increaseTo(startTime+2000);
     let res = await phxfarmproxyinst.totalStaked(0);
     console.log("totalstaked=" + res);

    let block = await web3.eth.getBlock("latest");
     console.log("blocknum1=" + block.number)

    res = await phxfarmproxyinst.allPendingReward(0,staker1)
    console.log("phxfarmproxyinst=",res[0].toString(),res[1].toString(),res[2].toString());

     res = await phxfarmproxyinst.getPoolInfo(0)
     console.log("poolinf=",res[0].toString(),res[1].toString(),res[2].toString(),
     res[3].toString(),res[4].toString(),res[5].toString(),
     res[6].toString(),res[7].toString(),res[8].toString());

    res = await phxfarmproxyinst.getMineInfo(0);
    console.log(res[0].toString(),
                res[1].toString(),
                res[2].toString(),
                res[3].toString());

     let preBalance = web3.utils.fromWei(await cphx.balanceOf(staker1));
     let wasppreBalance = web3.utils.fromWei(await wasp.balanceOf(staker1));

     res = await phxfarmproxyinst.withdraw(0,0,{from:staker1});
     assert.equal(res.receipt.status,true);

     let afterBalance = web3.utils.fromWei(await cphx.balanceOf(staker1))
     console.log("cfnx reward=" + (afterBalance - preBalance));

     let waspafterBalance = web3.utils.fromWei(await wasp.balanceOf(staker1));
     console.log("wasp reward=" + (waspafterBalance - wasppreBalance));

     let lppreBalance = web3.utils.fromWei(await lp.balanceOf(staker1))
     res = await phxfarmproxyinst.withdraw(0,stakeAmount,{from:staker1});
     assert.equal(res.receipt.status,true);
     let lpafterBalance = web3.utils.fromWei(await lp.balanceOf(staker1))
     console.log("lp balance=" + (lpafterBalance - lppreBalance));
  })

  it("[0020] check staker2 mined balance,should pass", async()=>{
    let res = await phxfarmproxyinst.totalStaked(0);
    console.log("totalstaked=" + res);

    let block = await web3.eth.getBlock("latest");
    console.log("blocknum1=" + block.number)

    res = await phxfarmproxyinst.allPendingReward(0,staker2)
    console.log("phxfarmproxyinst=",res[0].toString(),res[1].toString(),res[2].toString());

    res = await phxfarmproxyinst.getPoolInfo(0)
    console.log("poolinf=",res[0].toString(),res[1].toString(),res[2].toString(),
      res[3].toString(),res[4].toString(),res[5].toString(),
      res[6].toString(),res[7].toString(),res[8].toString());

    res = await phxfarmproxyinst.getMineInfo(0);
    console.log(res[0].toString(),
      res[1].toString(),
      res[2].toString(),
      res[3].toString());

    let preBalance = web3.utils.fromWei(await cphx.balanceOf(staker2));
    let wasppreBalance = web3.utils.fromWei(await wasp.balanceOf(staker2));

    res = await phxfarmproxyinst.withdraw(0,0,{from:staker2});
    assert.equal(res.receipt.status,true);

    let afterBalance = web3.utils.fromWei(await cphx.balanceOf(staker2))
    console.log("cfnx reward=" + (afterBalance - preBalance));

    let waspafterBalance = web3.utils.fromWei(await wasp.balanceOf(staker2));
    console.log("wasp reward=" + (waspafterBalance - wasppreBalance));

    let lppreBalance = web3.utils.fromWei(await lp.balanceOf(staker2))
    res = await phxfarmproxyinst.withdraw(0,stakeAmount,{from:staker2});
    assert.equal(res.receipt.status,true);
    let lpafterBalance = web3.utils.fromWei(await lp.balanceOf(staker2))
    console.log("lp balance=" + (lpafterBalance - lppreBalance));
  })

})