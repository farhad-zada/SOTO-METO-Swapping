// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

error Swap__ZeroAmount(uint amount);
error Swap__NotEnoughBalance(uint balance);
error Swap__TransferFailed(string token);
error Swap__NotEnoughAllowance(uint256 allowance);
error Swao__NotEnoughRewards(uint256 amount);
error Swap__OutOfRange(uint256 value);
error Swap__OnlyOneTokenWithValue();

contract SwappingMetoSoto is OwnableUpgradeable {
    uint256 private metoReserve;
    uint256 private sotoReserve;
    uint256 private collectedMetoFees;
    uint256 private collectedSotoFees;
    uint256 private feePercentTopForMeto;
    uint256 private feePercentTopForSoto;
    uint256 private feePercentBase;
    uint256 private metoWeight;
    uint256 private sotoWeight;
    uint256 private metoRewards;
    uint256 private sotoRewards;

    IERC20Upgradeable private constant METO =
        IERC20Upgradeable(0xddaAd340b0f1Ef65169Ae5E41A8b10776a75482d);
    IERC20Upgradeable private constant SOTO =
        IERC20Upgradeable(0x0fC5025C764cE34df352757e82f7B5c4Df39A836);

    event Swap(address from, address to, uint256 token0, uint256 token1);
    event AddLiquidity(address who, uint256 amount0, uint256 amount1);
    event RemoveLiquidity(address who, uint256 amount0, uint256 amount1);
    event Withdraw(address who, uint256 amount);

    function initialize() public initializer {
        __Ownable_init();
        feePercentTopForMeto = 10e18;
        feePercentTopForSoto = 10e18;
        feePercentBase = 10e18;
        metoWeight = 10e18;
        sotoWeight = 10e18;
    }

    /* State Write Functions */

    function swapMetoForSoto(uint256 metoAmount) public {
        // recieves METO => sends SOTO
        if (metoAmount == 0) revert Swap__ZeroAmount({amount: metoAmount});

        uint256 sotoAmount = getAmountOut(0, metoAmount);
        uint256 feeSoto = getFeeForSoto(sotoAmount);
        uint256 allowance = METO.allowance(msg.sender, address(this));

        if (allowance < metoAmount)
            revert Swap__NotEnoughAllowance({allowance: allowance}); //test
        if (sotoReserve < sotoAmount)
            revert Swap__NotEnoughBalance({balance: sotoReserve}); //test

        //INTENTION: state modify
        sotoReserve -= (sotoAmount - feeSoto);
        metoReserve += metoAmount;
        sotoRewards += feeSoto;

        if (!METO.transferFrom(msg.sender, address(this), metoAmount))
            revert Swap__TransferFailed("M");
        if (!SOTO.transfer(msg.sender, sotoAmount - feeSoto))
            revert Swap__TransferFailed("S");

        emit Swap(address(METO), address(SOTO), metoAmount, sotoAmount);
    }

    function swapSotoForMeto(uint256 sotoAmount) public {
        // recieves SOTO => sends METO
        if (sotoAmount == 0) revert Swap__ZeroAmount({amount: sotoAmount});

        uint256 metoAmount = getAmountOut(sotoAmount, 0);
        uint256 feeMeto = getFeeForMeto(metoAmount);
        uint256 allowance = SOTO.allowance(msg.sender, address(this));

        if (allowance < sotoAmount)
            revert Swap__NotEnoughAllowance({allowance: allowance}); //test
        if (metoReserve < metoAmount)
            revert Swap__NotEnoughBalance({balance: metoReserve}); //test

        //INTENTION: state modify
        sotoReserve += sotoAmount;
        metoReserve -= (metoAmount - feeMeto);
        metoRewards += feeMeto;

        if (!SOTO.transferFrom(msg.sender, address(this), sotoAmount))
            revert Swap__TransferFailed("S");
        if (!METO.transfer(msg.sender, metoAmount - feeMeto))
            revert Swap__TransferFailed("M");

        emit Swap(address(SOTO), address(METO), sotoAmount, metoAmount);
    }

    function swapMetoForExactSoto(uint256 sotoAmount) public {
        // recieves METO => sends SOTO
        if (sotoAmount == 0) revert Swap__ZeroAmount({amount: sotoAmount});

        uint256 metoAmount = getAmountOut(sotoAmount, 0);
        uint256 feeSoto = getFeeForSoto(sotoAmount);
        uint256 allowance = METO.allowance(msg.sender, address(this));

        if (allowance < metoAmount)
            revert Swap__NotEnoughAllowance({allowance: allowance}); //test
        if (sotoReserve < sotoAmount)
            revert Swap__NotEnoughBalance({balance: sotoReserve}); //test

        //INTENTION: state modify
        sotoReserve -= (sotoAmount - feeSoto);
        metoReserve += metoAmount;
        sotoRewards += feeSoto;

        if (!METO.transferFrom(msg.sender, address(this), metoAmount))
            revert Swap__TransferFailed("M");
        if (!SOTO.transfer(msg.sender, sotoAmount - feeSoto))
            revert Swap__TransferFailed("S");

        emit Swap(address(SOTO), address(METO), sotoAmount, metoAmount);
    }

    function swapSotoForExactMeto(uint256 metoAmount) public {
        // recieves SOTO => sends METO
        if (metoAmount == 0) revert Swap__ZeroAmount({amount: metoAmount});

        uint256 sotoAmount = getAmountOut(0, metoAmount);
        uint256 feeMeto = getFeeForMeto(metoAmount);
        uint256 allowance = SOTO.allowance(msg.sender, address(this));

        if (allowance < sotoAmount)
            revert Swap__NotEnoughAllowance({allowance: allowance}); //test
        if (metoReserve < metoAmount)
            revert Swap__NotEnoughBalance({balance: metoReserve}); //test

        //INTENTION: state modify
        sotoReserve += sotoAmount;
        metoReserve -= (metoAmount - feeMeto);
        metoRewards += feeMeto;

        if (!SOTO.transferFrom(msg.sender, address(this), sotoAmount))
            revert Swap__TransferFailed("S");
        if (!METO.transfer(msg.sender, metoAmount - feeMeto))
            revert Swap__TransferFailed("M");

        emit Swap(address(SOTO), address(METO), sotoAmount, metoAmount);
    }

    function addLiquidity(
        uint256 amountMeto,
        uint256 amountSoto
    ) public onlyOwner {
        amountMeto = amountMeto * 10e18;
        amountSoto = amountSoto * 10e18;

        uint256 balanceMeto = METO.balanceOf(msg.sender);
        uint256 balanceSoto = SOTO.balanceOf(msg.sender);

        if (balanceMeto < amountMeto)
            revert Swap__NotEnoughBalance({balance: balanceMeto}); //test
        if (balanceSoto < amountSoto)
            revert Swap__NotEnoughBalance({balance: balanceSoto}); //test

        if (!METO.transferFrom(msg.sender, address(this), amountMeto))
            revert Swap__TransferFailed({token: "METO"}); //test
        if (!SOTO.transferFrom(msg.sender, address(this), amountSoto))
            revert Swap__TransferFailed({token: "SOTO"}); //test

        //INTENTION: state modify
        sotoReserve += amountSoto;
        metoReserve += amountMeto;

        emit AddLiquidity(msg.sender, amountMeto, amountSoto);
    }

    function removeLiquidit(
        uint256 amountMeto,
        uint256 amountSoto
    ) public onlyOwner {
        amountMeto = amountMeto * 10e18;
        amountSoto = amountSoto * 10e18;
        uint256 balanceMeto = METO.balanceOf(msg.sender);
        uint256 balanceSoto = SOTO.balanceOf(msg.sender);
        if (balanceMeto < amountMeto)
            revert Swap__NotEnoughBalance({balance: balanceMeto}); //test
        if (balanceSoto < amountSoto)
            revert Swap__NotEnoughBalance({balance: balanceSoto}); //test

        //INTENTION: state modify
        sotoReserve -= amountSoto;
        metoReserve -= amountMeto;

        if (!METO.transfer(msg.sender, amountMeto))
            revert Swap__TransferFailed({token: "METO"}); //test
        if (!SOTO.transfer(msg.sender, amountSoto))
            revert Swap__TransferFailed({token: "SOTO"}); //test

        emit RemoveLiquidity(msg.sender, amountMeto, amountSoto);
    }

    function claim() public onlyOwner {
        if (metoRewards == 0)
            revert Swao__NotEnoughRewards({amount: metoRewards});
        if (sotoRewards == 0)
            revert Swao__NotEnoughRewards({amount: sotoRewards});

        if (!METO.transfer(msg.sender, metoRewards))
            revert Swap__TransferFailed({token: "METO"});
        if (!SOTO.transfer(msg.sender, sotoRewards))
            revert Swap__TransferFailed({token: "METO"});
    }

    function setMetoFeePercent(uint256 _feePercentTopForMeto) public onlyOwner {
        if (_feePercentTopForMeto < 100 || 10000 < _feePercentTopForMeto)
            revert Swap__OutOfRange({value: _feePercentTopForMeto});
        //INTENTION: state modify
        feePercentTopForMeto = _feePercentTopForMeto * 10e14;
    }

    function setSotoFeePercent(uint256 _feePercentTopForSoto) public onlyOwner {
        if (_feePercentTopForSoto < 100 || 10000 < _feePercentTopForSoto)
            revert Swap__OutOfRange({value: _feePercentTopForSoto});
        //INTENTION: state modify
        feePercentTopForMeto = _feePercentTopForSoto * 10e14;
    }

    function withdrawNative(uint256 amount) public payable onlyOwner {
        uint256 balance = address(this).balance;
        if (balance < amount) revert Swap__NotEnoughBalance({balance: balance});
        address payable to = payable(msg.sender);
        (bool sent, ) = to.call{value: msg.value}("");
        if (!sent) revert Swap__TransferFailed({token: "NATIVE"});
        emit Withdraw(msg.sender, amount);
    }

    function setWeights(
        uint256 _sotoWeight,
        uint256 _metoWeight
    ) public onlyOwner {
        metoWeight = _metoWeight * 10e18;
        sotoWeight = _sotoWeight * 10e18;
    }

    /* State Helper Funcs */

    function getFeeForMeto(uint256 amount) public view returns (uint256) {
        return amount - (amount * feePercentTopForMeto) / feePercentBase;
    }

    function getFeeForSoto(uint256 amount) public view returns (uint256) {
        return amount - (amount * feePercentTopForSoto) / feePercentBase;
    }

    function getAmountOut(
        uint256 soto,
        uint256 meto
    ) public view returns (uint256) {
        if (0 < soto && 0 < meto) revert Swap__OnlyOneTokenWithValue();

        if (meto > 0) {
            return (meto * metoWeight) / sotoWeight;
        } else {
            return (soto * sotoWeight) / metoWeight;
        }
    }

    /* State Read Functions */

    function getMetoReserve() public view returns (uint256) {
        return metoReserve;
    }

    function getSotoReserve() public view returns (uint256) {
        return sotoReserve;
    }

    function getMetoFeePercent() public view returns (uint256) {
        return feePercentTopForMeto;
    }

    function getSotoWeight() public view returns (uint256) {
        return sotoWeight;
    }

    function getMetoWeight() public view returns (uint256) {
        return metoWeight;
    }
}
