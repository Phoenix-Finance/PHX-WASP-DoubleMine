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
    let time1;

    let stakeAmount = web3.utils.toWei('100', 'ether');
    let userLpAmount = web3.utils.toWei('1000', 'ether');
    let staker1 = accounts[1];
    let staker2 = accounts[2];

    let fnxMineAmount = web3.utils.toWei('1000000', 'ether');
    let disSpeed = web3.utils.toWei('1', 'ether');
    let interval = 1;

    let disSpeed2 = web3.utils.toWei('2', 'ether');
    let interval2 = 2;

    let minutes = 60;
    let hour    = 60*60;
    let day     = 24*hour;
    let finishTime;
    let startTIme;
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

        await fnxToken.adminSetBalance(proxy.address,fnxMineAmount);

      //set mine coin info
       let res = await proxy.setPoolMineAddress(lpToken1.address,fnxToken.address);
        assert.equal(res.receipt.status,true);
        //set mine coin info
        res = await proxy.setMineRate(disSpeed,interval);
        assert.equal(res.receipt.status,true);

        //set finshied time
        time1 = await tokenFactory.getBlockTime();
        res = await proxy.setPeriodFinish(time1,time1 + day);
        startTIme = time1;
        finishTime = time1 + day;
        assert.equal(res.receipt.status,true);

    })


   it("[0010] stake test and check mined balance,should pass", async()=>{

      let preMinerBalance = await proxy.totalRewards(staker1);
      console.log("before mine balance = " + preMinerBalance);

      let res = await lpToken1.approve(proxy.address,stakeAmount,{from:staker1});
      res = await proxy.stake(stakeAmount,"0x0",{from:staker1});
      time1 = await tokenFactory.getBlockTime();
      console.log(time1.toString(10));

      //check totalStaked function
      let totalStaked = await proxy.totalStaked();
      assert.equal(totalStaked,stakeAmount);

      let bigin = await web3.eth.getBlockNumber();
      console.log("start block="+ bigin )
      await utils.pause(web3,bigin + 1);

      let time2 = await tokenFactory.getBlockTime();
      //console.log(time2.toString(10));

      let afterMinerBalance = await proxy.totalRewards(staker1);
      console.log("after mine balance = " + afterMinerBalance);

      let diff = web3.utils.fromWei(afterMinerBalance) - web3.utils.fromWei(preMinerBalance);
      //console.log("time diff=" + (time2 - time1));
      let timeDiff = time2 - time1;

      console.log("mine balance = " + diff);
      assert.equal(diff>=timeDiff&&diff<=diff*(timeDiff+1),true);
		})

  it("[0020]get out mine reward,should pass", async()=>{
    console.log("\n\n");
    let preMinedAccountBalance = await fnxToken.balanceOf(staker1);
    console.log("before mined token balance="+preMinedAccountBalance);

    let time2 = await tokenFactory.getBlockTime();
    console.log(time2.toString(10));

    let timeDiff = time2 - time1;
    console.log("timeDiff=" + timeDiff);

    let res = await proxy.getReward({from:staker1});
    assert.equal(res.receipt.status,true);

    let afterMineAccountBalance = await fnxToken.balanceOf(staker1);
    console.log("after mined account balance = " + afterMineAccountBalance);

    let diff = web3.utils.fromWei(afterMineAccountBalance) - web3.utils.fromWei(preMinedAccountBalance);

    console.log("mine reward = " + diff);

    assert.equal(diff>=timeDiff&&diff<=(timeDiff+1),true);
  })


  it("[0030] stake out,should pass", async()=>{
    console.log("\n\n");
    let preLpBlance = await lpToken1.balanceOf(staker1);
    console.log("preLpBlance=" + preLpBlance);

    let preStakeBalance = await proxy.totalStakedFor(staker1);
    console.log("before mine balance = " + preStakeBalance);

    let res = await proxy.unstake(preStakeBalance,"0x0",{from:staker1});
    assert.equal(res.receipt.status,true);

    let afterStakeBalance = await proxy.totalStakedFor(staker1);
    console.log("after mine balance = " + afterStakeBalance);

    let diff = web3.utils.fromWei(preStakeBalance) - web3.utils.fromWei(afterStakeBalance);
    console.log("stake out balance = " + diff);

    let afterLpBlance = await lpToken1.balanceOf(staker1);
    console.log("afterLpBlance=" + afterLpBlance);
    let lpdiff = web3.utils.fromWei(afterLpBlance) - web3.utils.fromWei(preLpBlance);

    assert.equal(diff,lpdiff);
  })


  it("[0050] get back left mining token,should pass", async()=>{
    console.log("\n\n");
    let preMineBlance = await fnxToken.balanceOf(proxy.address);
    console.log("preMineBlance=" + preMineBlance);

    let preRecieverBalance = await fnxToken.balanceOf(staker1);
    console.log("before mine balance = " + preRecieverBalance);

    let res = await proxy.getbackLeftMiningToken(staker1);
    assert.equal(res.receipt.status,true);

    let afterRecieverBalance = await  fnxToken.balanceOf(staker1);
    console.log("after mine balance = " + afterRecieverBalance);

    let diff = web3.utils.fromWei(afterRecieverBalance) - web3.utils.fromWei(preRecieverBalance);
    console.log("stake out balance = " + diff);

    let afterMineBlance = await fnxToken.balanceOf(proxy.address);
    console.log("afterMineBlance=" + afterMineBlance);

    let lpdiff = web3.utils.fromWei(preMineBlance) - web3.utils.fromWei(afterMineBlance);
    assert.equal(diff,lpdiff);

  })

  it("[0050] get back left mining token,should pass", async()=>{
     let res = await proxy.getMineInfo();
     console.log(res);

     assert.equal( web3.utils.fromWei(res[0]), web3.utils.fromWei(disSpeed));
     assert.equal(res[1].toNumber(),interval);
     assert.equal(res[2].toNumber(),startTIme);
     assert.equal(res[3].toNumber(),finishTime);
  })

})
