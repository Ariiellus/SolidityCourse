pragma solidity 0.8.20; //Do not change the solidity version as it negatively impacts submission grading
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "./YourToken.sol";

contract Vendor is Ownable {
    // event BuyTokens(address buyer, uint256 amountOfETH, uint256 amountOfTokens);
    uint256 public constant tokensPerEth = 100;
    event BuyTokens(address buyer, uint256 amountOfETH, uint256 tokensPerEth);
    event SellTokens(address seller, uint256 amountOfTokens, uint256 amountOfETH);

    YourToken public yourToken;
    // previously called SecurityResearcherDreamToken $SRDT
    // now called Gold $GLD due previous error uploading the challenge to SpeedRunEthereum
    // Ariiellus was here

    constructor(address tokenAddress) Ownable(msg.sender) {
        yourToken = YourToken(tokenAddress);
    }

    function buyTokens() public payable {
        uint256 tokensToBuy = msg.value * tokensPerEth;
        yourToken.transfer(msg.sender, tokensToBuy);
        emit BuyTokens(msg.sender, msg.value, tokensToBuy);
    }

    function sellTokens(uint256 _amount) public payable {
        uint256 amountOfETH = _amount / tokensPerEth;
        yourToken.transferFrom(msg.sender, address(this), _amount);
        emit SellTokens(msg.sender, _amount, amountOfETH);
        payable(msg.sender).transfer(amountOfETH);
    }

    function withdraw() public {
        require(msg.sender == owner(), "Sorry mate, you are not the owner");
        payable(msg.sender).transfer(address(this).balance);
    }

}
