// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenPool} from "@chainlink/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {Pool} from "@chainlink/contracts/src/v0.8/ccip/libraries/Pool.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract RebaseTokenPool is TokenPool {
    constructor(
        IERC20 _token,
        address[] memory _allowlist,
        address _rnmProxy,
        address _router
    ) TokenPool(_token, _allowlist, _rnmProxy, _router) {}

    function lockOrBurn(
        Pool.LockOrBurnInV1 calldata lockOrBurnIn
    ) public virtual override returns (Pool.LockOrBurnOutV1 memory) {
      _validateLockOrBurn(lockOrBurnIn);
      address receiver = abi.decode(lockOrBurnIn.receiver, (address));
      uint256 userInteresRate = IRebaseToken(address(i_token)).getUserInterestRate(receiver);
      IRebaseToken(address(i_token)).burn(receiver, lockOrBurnIn.amount);
      
      return Pool.LockOrBurnOutV1({
        destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
        destPoolData: abi.encode(userInteresRate)
      });
    }

    function releaseOrMint(
        Pool.ReleaseOrMintInV1 calldata releaseOrMintIn
    ) public virtual override returns (Pool.ReleaseOrMintOutV1 memory) {
      _validateReleaseOrMint(releaseOrMintIn);
      uint256 userInteresRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
      IRebaseToken(address(i_token)).mint(releaseOrMintIn.receiver, releaseOrMintIn.amount, userInteresRate);

      return Pool.ReleaseOrMintOutV1({
        destinationAmount: releaseOrMintIn.amount
      });
    }
}
