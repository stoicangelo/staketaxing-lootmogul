const { expect } = require('chai');
const { ethers } = require('hardhat');



describe("SushiBar", function () {
  before(async function () {
    this.SushiToken = await ethers.getContractFactory("SushiToken")
    this.SushiBar = await ethers.getContractFactory("SushiBar")

    this.signers = await ethers.getSigners()
    this.alice = this.signers[0]
    this.bob = this.signers[1]
    this.carol = this.signers[2]
  })

  beforeEach(async function () {
    this.sushi = await this.SushiToken.deploy()
    this.bar = await this.SushiBar.deploy(this.sushi.address)
    this.sushi.mint(this.alice.address, "100")
    this.sushi.mint(this.bob.address, "100")
    this.sushi.mint(this.carol.address, "100")
  })

  it("should not allow enter if not enough approve", async function () {
    await expect(this.bar.enter("100")).to.be.revertedWith("ERC20: insufficient allowance")
    await this.sushi.approve(this.bar.address, "50")
    await expect(this.bar.enter("100")).to.be.revertedWith("ERC20: insufficient allowance")
    await this.sushi.approve(this.bar.address, "100")
    await this.bar.enter("100")
    expect(await this.bar.balanceOf(this.alice.address)).to.equal("100")
  })

  it("should not allow withdraw more than staked", async function () {
    await this.sushi.approve(this.bar.address, "100")
    await this.bar.enter("100")
    await expect(this.bar.leave("200")).to.be.revertedWith("Insufficient xSUSHI")
  })

  it("should not allow withdraw before 2 days", async function () {
    await this.sushi.approve(this.bar.address, "100")
    await this.bar.enter("100")
    await expect(this.bar.leave("80")).to.be.revertedWith("Cannot be unstacked before 2 days")
  })

})
