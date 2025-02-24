// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IGob} from "./interfaces/IGob.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAirdropDistributor} from "./interfaces/IAirdropDistributor.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AirdropDistributor is IAirdropDistributor, Ownable {
    using SafeERC20 for IGob;
    /// @inheritdoc IAirdropDistributor
    IGob public immutable gob;
    /// @inheritdoc IAirdropDistributor
    IVotingEscrow public immutable ve;

    constructor(address _ve) {
        ve = IVotingEscrow(_ve);
        gob = IGob(IVotingEscrow(_ve).token());
    }

    /// @inheritdoc IAirdropDistributor
    function distributeTokens(address[] memory _wallets, uint256[] memory _amounts) external override onlyOwner {
        uint256 _len = _wallets.length;
        if (_len != _amounts.length) revert InvalidParams();
        uint256 _sum;
        for (uint256 i = 0; i < _len; i++) {
            _sum += _amounts[i];
        }

        if (_sum > gob.balanceOf(address(this))) revert InsufficientBalance();
        gob.safeApprove(address(ve), _sum);
        address _wallet;
        uint256 _amount;
        uint256 _tokenId;
        for (uint256 i = 0; i < _len; i++) {
            _wallet = _wallets[i];
            _amount = _amounts[i];
            // _tokenId = ve.createLock(_amount, 1 weeks);
            _tokenId = ve.createLock(_amount, 1 days);
            ve.lockPermanent(_tokenId);
            ve.safeTransferFrom(address(this), _wallet, _tokenId);
            emit Airdrop(_wallet, _amount, _tokenId);
        }
        gob.safeApprove(address(ve), 0);
    }
}
