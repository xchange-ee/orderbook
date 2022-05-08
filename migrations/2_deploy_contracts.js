const Exchange = artifacts.require('Exchange')
const BRZ = artifacts.require('BRZ')
const BLU = artifacts.require('BLU')

module.exports = function (deployer) {}

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(Exchange)
  await deployer.deploy(BRZ, 'BRZ', 1000000000000, {
    from: accounts[0],
  })

  await deployer.deploy(BLU, 'BLU', 1000000000000, {
    from: accounts[1],
  })
}
