// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./Base.sol";

contract Deposits is Base {
    using SafeERC20 for IERC20;

    /**
    * @dev Deposit funds to the vault. Can only be called if the committee had
    * checked in and deposits are not paused.
    * NOTE: Vaults should not use tokens which do not guarantee that the 
    * amount specified is the amount transferred
    * @param caller Caller of the action (msg.sender)
    * @param receiver Reciever of the shares from the deposit
    * @param assets Amount of vault's native token to deposit
    * @param shares Respective amount of shares to be received
    */
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal override virtual nonReentrant {
        if (!committeeCheckedIn)
            revert CommitteeNotCheckedInYet();
        if (shares == 0) revert AmountToDepositIsZero();
        if (withdrawEnableStartTime[receiver] != 0 && receiver == caller) {
            // clear withdraw request
            withdrawEnableStartTime[receiver] = 0;
        }

        super._deposit(caller, receiver, assets, shares);
    }
}