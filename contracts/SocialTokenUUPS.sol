// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC20Upgradeable, ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

contract SocialToken is
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    OwnableUpgradeable
{
    function initialize(
        string memory name_,
        string memory symbol_
    ) public initializer {
        __Ownable_init();
        __ERC20_init(name_, symbol_);
        setAdminAddress(msg.sender, true);
    }

    mapping(address => bool) private adminAddresses;

    modifier admin() {
        require(adminAddresses[msg.sender], "SOTO: not admin");
        _;
    }

    function mint(address account, uint256 amount) public admin {
        _mint(account, amount);
    }

    function burnOf(address account, uint256 amount) public admin {
        _burn(account, amount);
    }

    function burnFrom(address account, uint256 amount) public override admin {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }

    function setAdminAddress(address account, bool status) public onlyOwner {
        adminAddresses[account] = status;
    }

    function renounceAdminship() public admin {
        adminAddresses[msg.sender] = false;
    }

    function isAdmin(address account) public view returns (bool) {
        return adminAddresses[account];
    }
}
