// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SushiBar is ERC20("SushiBar", "xSUSHI") {
    using SafeMath for uint256;

    IERC20 public sushi;
    uint public currentPositionId;

    struct Position {
        uint positionId;
        uint256 createdAt;
        address validator;
        uint256 amount;
    }
    mapping(uint => Position) public positions;
    mapping(address => uint[]) public positionsForValidator;

    constructor(IERC20 _sushi) {
        sushi = _sushi;
        currentPositionId = 0;
    }


    function enter(uint256 _amount) public {
        uint256 totalSushi = sushi.balanceOf(address(this));
        uint256 totalShares = totalSupply();
        uint256 xSushiAmount = 0;

        if (totalShares == 0 || totalSushi == 0) {
            xSushiAmount = _amount;
        }
        else {
            xSushiAmount = _amount.mul(totalShares).div(totalSushi);
        }
        _mint(msg.sender, xSushiAmount);

        sushi.transferFrom(msg.sender, address(this), _amount);

        positions[currentPositionId] = Position(
            currentPositionId,
            block.timestamp,
            msg.sender,
            xSushiAmount
        );
        positionsForValidator[msg.sender].push(currentPositionId);
        currentPositionId += 1;
    }


    function leave(uint256 _share) public {

        require(this.balanceOf(msg.sender) > _share, "Insufficient xSUSHI");
        uint256 sum = 0;
        uint sufficientPositionCount = 0;
        uint numberOfPositions = positionsForValidator[msg.sender].length;
        require(numberOfPositions > 0, "Not a validator yet");
        //store the minimum positions required to fulfill the leave operation, chronologically
        Position[] memory positionsHeld = new Position[](numberOfPositions);
        for (uint i = 0; i < numberOfPositions; i++) {
            uint positionAmount = positions[positionsForValidator[msg.sender][i]].amount;
            if (positionAmount <= 0) {
                continue;
            }
            sum += positionAmount;
            sufficientPositionCount += 1;
            positionsHeld[i] = positions[positionsForValidator[msg.sender][i]];
            if (sum >= _share) {
                break;
            }
        }
        require(block.timestamp > positionsHeld[sufficientPositionCount-1].createdAt + 2 * 1 days, "Cannot be unstacked before 2 days");

        uint256 totalShares = totalSupply();
        uint256 what = _share.mul(sushi.balanceOf(address(this))).div(
            totalShares
        );

        uint256 unstackableAmount = 0;
        if (block.timestamp < positionsHeld[sufficientPositionCount-1].createdAt + 4 * 1 days) {
            unstackableAmount = what.mul(25).div(100);
        } else if (block.timestamp < positionsHeld[sufficientPositionCount-1].createdAt + 6 * 1 days) {
            unstackableAmount = what.mul(50).div(100);
        } else if (block.timestamp < positionsHeld[sufficientPositionCount-1].createdAt + 8 * 1 days) {
            unstackableAmount = what.mul(75).div(100);
        }

        _burn(msg.sender, _share);
        // when we are doing partial transfer of SUSHI, the remaining is naturally staying in the sushi contract.
        sushi.transfer(msg.sender, unstackableAmount);

        //modify the positions which were used up in the leave OP
        uint256 unstakedAmountxSUSHI = 0;
        for (uint i = 0; i < sufficientPositionCount; i++) {
            if (unstakedAmountxSUSHI + positionsHeld[i].amount >= _share) {
                positions[positionsHeld[i].positionId].amount = unstakedAmountxSUSHI + positionsHeld[i].amount - _share;
                break;
            } else {
                positions[positionsHeld[i].positionId].amount = 0;
            }
            unstakedAmountxSUSHI += positionsHeld[i].amount;
        } 
    }
}
