const Exchange = artifacts.require('./Exchange')

const Token = artifacts.require('Token')

contract('Exchange - manager', async (accounts) => {
  const account1 = accounts[0]
  const account2 = accounts[1]

  it('add token', async () => {
    let BRz = await Token.deployed()
    let exchange = await Exchange.deployed()
    await exchange.addToken(BRz.address)
    const tokens = await exchange.listTokens.call({
      from: account1,
    })

    console.log(tokens)
    assert.equal(tokens.length, 1)
  })
})
