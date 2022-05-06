const Exchange = artifacts.require('Exchange')
const Token = artifacts.require('Token')

module.exports = function (deployer) {}

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(Exchange)
  await deployer.deploy(Token, 'BRZ', 100000000000, {
    from: accounts[0],
  })
}
