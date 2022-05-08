const Exchange = artifacts.require('./Exchange')

const BRZ = artifacts.require('BRZ')
const BLU = artifacts.require('BLU')

contract('Exchange - manager', async (accounts) => {
  const account1 = accounts[0]
  const account2 = accounts[1]

  it('add token', async () => {
    let brz = await BRZ.deployed()
    let blu = await BLU.deployed()
    let exchange = await Exchange.deployed()
    await exchange.addToken(brz.address)
    await exchange.addToken(blu.address)
    const tokens = await exchange.listTokens.call({
      from: account1,
    })
    assert.equal(tokens.length, 2)
  })

  it('add pair', async () => {
    let brz = await BRZ.deployed()
    let blu = await BLU.deployed()
    let exchange = await Exchange.deployed()

    await exchange.addPair(brz.address, blu.address)
    const pairs = await exchange.listPairs.call({
      from: account1,
    })
    assert.equal(pairs.length, 1)
  })

  it('remove pair', async () => {
    let brz = await BRZ.deployed()
    let blu = await BLU.deployed()
    let exchange = await Exchange.deployed()
    await exchange.removePair(brz.address, blu.address)
    const pairs = await exchange.listPairs.call({
      from: account1,
    })
    assert.equal(pairs.length, 0)
  })
})
