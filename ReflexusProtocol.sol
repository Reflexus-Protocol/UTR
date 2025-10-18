// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts@4.9.3/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.9.3/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts@4.9.3/access/Ownable2Step.sol";
import "@openzeppelin/contracts@4.9.3/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts@4.9.3/utils/math/Math.sol";

contract ReflexusProtocolFixed is ReentrancyGuard, ERC20, ERC20Permit, Ownable2Step {
    uint256 public immutable TOTAL_SUPPLY;
    uint256 public immutable BURNING_LIMIT;
    uint256 public immutable MINIMUM_PURCHASE_NATIVE;
    uint256 private immutable BASE_PRICE;
    uint256 private constant PRECISION_DIVISOR = 10000;

    uint256 private constant EFFECTIVE_BACKING_NUMERATOR = 999;
    uint256 private constant EFFECTIVE_BACKING_DENOMINATOR = 1000;

    uint256 private immutable BUY_DEV_FEE_BPS;
    uint256 private immutable BUY_RESERVE_FEE_BPS;
    uint256 private immutable BUY_REFLECTION_FEE_BPS;
    
    uint256 private immutable REFUND_DEV_FEE_BPS;
    uint256 private immutable REFUND_REFLECTION_FEE_BPS;
    
    uint256 private immutable TRANSFER_DEV_FEE_BPS;
    uint256 private immutable TRANSFER_REFLECTION_FEE_BPS;
    uint256 private immutable TRANSFER_RESERVE_FEE_BPS;
    
    uint256 private immutable DEX_SWAP_DEV_FEE_BPS;
    uint256 private immutable DEX_SWAP_REFLECTION_FEE_BPS;
    uint256 private immutable DEX_SWAP_RESERVE_FEE_BPS;

    uint256 public totalBurned;
    uint256 public tokensSold;
    address private devAddress;
    
    uint256 private constant MAGNITUDE = 2**128;
    uint256 private magnifiedDividendPerShare;
    uint256 private totalDividendsDistributed;
    
    mapping(address => uint256) private lastDividendPerShare;
    mapping(address => uint256) private accumulatedDividends;
    
    mapping(address => bool) private _isExcludedFromFee;
    
    mapping(address => bool) private _isLiquidityPair;
    mapping(address => bool) private _isNotLiquidityPair;

    error ReflexusAddress();
    error ReflexusAmount();
    error InsufficientBalance();
    error InsufficientNative();
    error NoTokensInCirculation();
    error NativeTransferFailed();
    error DividendsOverflow();

    enum SwapType { BUY, SELL }
    enum ExemptionReason { REFUND, EXCLUDED_ADDRESS }

    event Buy(address indexed buyer, uint256 nativePaid, uint256 utrReceived);
    event Refund(address indexed refunder, uint256 utrRefunded, uint256 nativeReceived);
    event TransferFeeApplied(address indexed from, address indexed to, uint256 originalAmount, uint256 devFee, uint256 reflectionFee, uint256 reserveFee, uint256 netAmount);
    event SwapFeeApplied(SwapType swapType, address indexed user, uint256 originalAmount, uint256 devFee, uint256 reflectionFee, uint256 reserveFee, uint256 netAmount);
    event TransferFeeExempt(address indexed from, address indexed to, uint256 amount, ExemptionReason reason);
    event DividendsDistributed(uint256 amount, uint256 magnifiedDividendPerShare);
    event DividendWithdrawn(address indexed user, uint256 amount);
    event LiquidityPairDetected(address indexed pair);
    event DevAddressChanged(address indexed oldDevAddress, address indexed newDevAddress);
    event FeeExclusionSet(address indexed account, bool isExcluded);

    constructor(address _initialOwner, address _devAddress) ERC20("Reflexus Protocol", "UTR") ERC20Permit("Reflexus Protocol") Ownable() payable {
        if (_initialOwner == address(0)) revert ReflexusAddress();
        if (_devAddress == address(0)) revert ReflexusAddress();

        TOTAL_SUPPLY = 1250000000 * 1e18;
        BURNING_LIMIT = TOTAL_SUPPLY / 5; 
        MINIMUM_PURCHASE_NATIVE = 0.0001 ether;
        BASE_PRICE = 0.0001 ether;

        BUY_DEV_FEE_BPS = 5;
        BUY_RESERVE_FEE_BPS = 10;
        BUY_REFLECTION_FEE_BPS = 10;
        
        REFUND_DEV_FEE_BPS = 5;   
        REFUND_REFLECTION_FEE_BPS = 5; 
        
        TRANSFER_DEV_FEE_BPS = 5;
        TRANSFER_REFLECTION_FEE_BPS = 10;
        TRANSFER_RESERVE_FEE_BPS = 10;
        
        DEX_SWAP_DEV_FEE_BPS = 5;
        DEX_SWAP_REFLECTION_FEE_BPS = 10;
        DEX_SWAP_RESERVE_FEE_BPS = 10;

        devAddress = _devAddress;

        _mint(address(this), TOTAL_SUPPLY);
        
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_initialOwner] = true;
        _isExcludedFromFee[devAddress] = true;
        
        if (msg.value != 0) {
           _buy(_devAddress, msg.value);
        }
        
        _transferOwnership(_initialOwner);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account);
    }

    function totalSupply() public view override returns (uint256) {
        return TOTAL_SUPPLY - totalBurned;
    }
    
    function buy() external payable {
        _buy(msg.sender, msg.value);
    }

    receive() external payable {
        _buy(msg.sender, msg.value);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        _update(from, to, amount);
    }
    
    function _afterTokenTransfer(address from, address to, uint256 amount) internal override {
        super._afterTokenTransfer(from, to, amount);
        
        if (from != address(0) && !isContract(from)) {
            _updateUserDividendTracking(from);
        }
        
        if (to != address(0) && !isContract(to)) {
            _updateUserDividendTracking(to);
        }
    }

    function _update(address from, address to, uint256 amount) private {
        if (from == address(0)) revert ReflexusAddress();
        if (to == address(0)) revert ReflexusAddress();
        if (amount == 0) revert ReflexusAmount();

        bool isExempt = _isExcludedFromFee[from] || _isExcludedFromFee[to];

        if (to == address(this)) {
            super._transfer(from, to, amount);
            _handleRefund(from, amount);
            emit TransferFeeExempt(from, to, amount, ExemptionReason.REFUND);
        } else if (isExempt) {
            super._transfer(from, to, amount);
            emit TransferFeeExempt(from, to, amount, ExemptionReason.EXCLUDED_ADDRESS);
        } else {
            _handleTaxedTransfer(from, to, amount);
        }
    }
    
    function isLiquidityPair(address addr) internal returns (bool) {
        if (addr.code.length == 0) {
            return false;
        }
        if (_isLiquidityPair[addr]) return true;
        if (_isNotLiquidityPair[addr]) return false;

        (bool s0, bytes memory d0) = addr.staticcall(abi.encodeWithSignature("token0()"));
        (bool s1, bytes memory d1) = addr.staticcall(abi.encodeWithSignature("token1()"));

        if (s0 && s1 && d0.length == 32 && d1.length == 32) {
            address token0 = abi.decode(d0, (address));
            address token1 = abi.decode(d1, (address));
            if ((token0 == address(this) || token1 == address(this)) && token0 != token1) {
                _cacheLiquidityPair(addr);
                return true;
            }
        }

        _isNotLiquidityPair[addr] = true;
        return false; 
    }

    function _cacheLiquidityPair(address addr) private {
        _isLiquidityPair[addr] = true;
        emit LiquidityPairDetected(addr);
    }

    function _handleTaxedTransfer(address from, address to, uint256 amount) private {
        if (balanceOf(from) < amount) revert InsufficientBalance();

        bool isDexSwap = (isContract(from) && isLiquidityPair(from)) || (isContract(to) && isLiquidityPair(to));

        uint256 devFeeBps;
        uint256 reflectionFeeBps;
        uint256 reserveFeeBps;

        if (isDexSwap) {
            devFeeBps = DEX_SWAP_DEV_FEE_BPS;
            reflectionFeeBps = DEX_SWAP_REFLECTION_FEE_BPS;
            reserveFeeBps = DEX_SWAP_RESERVE_FEE_BPS;
        } else {
            devFeeBps = TRANSFER_DEV_FEE_BPS;
            reflectionFeeBps = TRANSFER_REFLECTION_FEE_BPS;
            reserveFeeBps = TRANSFER_RESERVE_FEE_BPS;
        }

        uint256 devFee = Math.mulDiv(amount, devFeeBps, 10000);
        uint256 reflectionFee = Math.mulDiv(amount, reflectionFeeBps, 10000);
        uint256 reserveFee = Math.mulDiv(amount, reserveFeeBps, 10000);
        uint256 netAmount;
        unchecked {
            netAmount = amount - devFee - reflectionFee - reserveFee;
        }

        super._transfer(from, address(this), amount);
        if (netAmount != 0) {
            super._transfer(address(this), to, netAmount);
        }
        if (devFee != 0) {
            super._transfer(address(this), devAddress, devFee);
        }
        _distributeDividends(reflectionFee);

        if (isDexSwap) {
            bool isSell = isContract(to) && isLiquidityPair(to);
            address user = isSell ? from : to;
            emit SwapFeeApplied(isSell ? SwapType.SELL : SwapType.BUY, user, amount, devFee, reflectionFee, reserveFee, netAmount);
        } else {
            emit TransferFeeApplied(from, to, amount, devFee, reflectionFee, reserveFee, netAmount);
        }
    }
    
    function _buy(address buyer, uint256 amountNative) private nonReentrant {
        if (amountNative < MINIMUM_PURCHASE_NATIVE) revert InsufficientNative();

        uint256 balanceBefore = address(this).balance - amountNative;
        uint256 utrToPurchase = _getUtrForNative(amountNative, balanceBefore);

        if (utrToPurchase == 0) revert InsufficientNative();
        if (tokensSold + utrToPurchase > TOTAL_SUPPLY) revert InsufficientBalance();

        uint256 devFee = Math.mulDiv(utrToPurchase, BUY_DEV_FEE_BPS, 10000);
        uint256 reserveFee = Math.mulDiv(utrToPurchase, BUY_RESERVE_FEE_BPS, 10000);
        uint256 reflectionFee = Math.mulDiv(utrToPurchase, BUY_REFLECTION_FEE_BPS, 10000);
        uint256 utrToUser;
        unchecked {
            utrToUser = utrToPurchase - devFee - reserveFee - reflectionFee;
        }

        tokensSold = tokensSold + utrToPurchase;

        super._transfer(address(this), devAddress, devFee);
        super._transfer(address(this), buyer, utrToUser);
        
        _distributeDividends(reflectionFee);

        emit Buy(buyer, amountNative, utrToUser);
    }

    function _handleRefund(address sender, uint256 utrAmount) private nonReentrant {
        if (utrAmount == 0) revert ReflexusAmount();

        uint256 _totalBurned = totalBurned;

        uint256 devFeeUTR = Math.mulDiv(utrAmount, REFUND_DEV_FEE_BPS, 10000); 
        uint256 reflectionFeeUTR = Math.mulDiv(utrAmount, REFUND_REFLECTION_FEE_BPS, 10000); 
        uint256 burnFeeUTR = (_totalBurned < BURNING_LIMIT) ? Math.mulDiv(utrAmount, 75, 100000) : 0; 
        uint256 reserveFeeUTR = (_totalBurned < BURNING_LIMIT) ? Math.mulDiv(utrAmount, 75, 100000) : Math.mulDiv(utrAmount, 150, 100000); 
        uint256 utrForUserRefund;
        unchecked {
            utrForUserRefund = utrAmount - devFeeUTR - reflectionFeeUTR - burnFeeUTR - reserveFeeUTR;
        }

        uint256 contractBalance = balanceOf(address(this));
        uint256 currentCirculatingSupply = (TOTAL_SUPPLY - _totalBurned) - contractBalance + utrAmount;
        
        if (currentCirculatingSupply == 0) revert NoTokensInCirculation();

        uint256 effectiveBacking = (address(this).balance * EFFECTIVE_BACKING_NUMERATOR) / EFFECTIVE_BACKING_DENOMINATOR;
        uint256 grossNativeValue = (utrForUserRefund * effectiveBacking) / currentCirculatingSupply;
        uint256 nativeToUser = grossNativeValue; 

        if (address(this).balance < nativeToUser) revert InsufficientNative();

        if (devFeeUTR != 0) {
            super._transfer(address(this), devAddress, devFeeUTR);
        }
        if (burnFeeUTR != 0 && _totalBurned < BURNING_LIMIT) {
            uint256 remainingToBurn = BURNING_LIMIT - _totalBurned;
            if (burnFeeUTR > remainingToBurn) {
                burnFeeUTR = remainingToBurn;
            }
            if (burnFeeUTR != 0) {
                _burn(address(this), burnFeeUTR);
                totalBurned = totalBurned + burnFeeUTR;
            }
        }
        
        _distributeDividends(reflectionFeeUTR);

        emit Refund(sender, utrAmount, nativeToUser);

        (bool success, ) = sender.call{value: nativeToUser}("");
        if (!success) revert NativeTransferFailed();
    }

    function _distributeDividends(uint256 amount) private {
        if (amount == 0) return;
        
        uint256 circulatingSupply = getCirculatingSupply();
        if (circulatingSupply == 0) return;

        uint256 dividendPerShare = (amount * MAGNITUDE) / circulatingSupply;
        
        magnifiedDividendPerShare += dividendPerShare;
        totalDividendsDistributed += amount;
        
        emit DividendsDistributed(amount, magnifiedDividendPerShare);
    }

    function getCirculatingSupply() private view returns (uint256) {
        uint256 total = totalSupply();
        uint256 contractBalance = balanceOf(address(this)); // Contract's unsold tokens
                
        return total - contractBalance;
    }
    
    function _updateUserDividendTracking(address user) private {
        // Exclude contracts from dividend tracking
        if (isContract(user)) return;
        
        uint256 userBalance = balanceOf(user);
        if (userBalance == 0) return;
        
        uint256 currentDividendPerShare = magnifiedDividendPerShare;
        uint256 lastUserDividendPerShare = lastDividendPerShare[user];
        
        if (currentDividendPerShare > lastUserDividendPerShare) {
            uint256 dividendDifference = currentDividendPerShare - lastUserDividendPerShare;
            uint256 newDividends = (userBalance * dividendDifference) / MAGNITUDE;
            
            if (newDividends > 0) {
                accumulatedDividends[user] += newDividends;
            }
        }
        
        lastDividendPerShare[user] = currentDividendPerShare;
    }

    function claimDividends() external {
        address user = msg.sender;
        
        // Exclude contracts from dividend claiming
        if (isContract(user)) return;
        
        uint256 userBalance = balanceOf(user);
        if (userBalance == 0) return;
        
        uint256 currentDividendPerShare = magnifiedDividendPerShare;
        uint256 lastUserDividendPerShare = lastDividendPerShare[user];
        
        if (currentDividendPerShare > lastUserDividendPerShare) {
            uint256 dividendDifference = currentDividendPerShare - lastUserDividendPerShare;
            uint256 newDividends = (userBalance * dividendDifference) / MAGNITUDE;
            
            if (newDividends > 0) {
                accumulatedDividends[user] += newDividends;
            }
        }
        
        lastDividendPerShare[user] = currentDividendPerShare;
        
        uint256 totalAccumulated = accumulatedDividends[user];
        if (totalAccumulated > 0) {
            accumulatedDividends[user] = 0;
            super._transfer(address(this), user, totalAccumulated);
            emit DividendWithdrawn(user, totalAccumulated);
        }
    }

    function pendingDividends(address user) external view returns (uint256) {
        
        if (isContract(user)) return 0;
        
        uint256 userBalance = balanceOf(user);
        if (userBalance == 0) return accumulatedDividends[user];
        
        uint256 currentDividendPerShare = magnifiedDividendPerShare;
        uint256 lastUserDividendPerShare = lastDividendPerShare[user];        
        
        if (currentDividendPerShare > lastUserDividendPerShare) {
            uint256 dividendDifference = currentDividendPerShare - lastUserDividendPerShare;
            uint256 newDividends = (userBalance * dividendDifference) / MAGNITUDE;
            return accumulatedDividends[user] + newDividends;
        }
        
        return accumulatedDividends[user];
    }

    function calculateUtrForNative(uint256 nativeAmount) public view returns (uint256) {
        return _getUtrForNative(nativeAmount, address(this).balance);
    }

    function _getUtrForNative(uint256 nativeAmount, uint256 balanceBefore) private view returns (uint256) {
        if (nativeAmount == 0) return 0;
        uint256 availableToSell = balanceOf(address(this));
        if (availableToSell == 0) return 0;

        uint256 circulating = totalSupply() - availableToSell;

        uint256 pricePerToken;
        if (circulating == 0 || balanceBefore == 0) {
            pricePerToken = BASE_PRICE;
        } else {
            uint256 refundPrice = (balanceBefore * 1e18) / circulating;
            pricePerToken = (refundPrice * 10010) / PRECISION_DIVISOR;
        }

        uint256 tokensToPurchase = (nativeAmount * 1e18) / pricePerToken;
        return Math.min(tokensToPurchase, availableToSell);
    }

    function isContract(address _addr) internal view returns (bool) {
        if (_addr.code.length == 0) return false;
        
        (bool s0, bytes memory d0) = _addr.staticcall(abi.encodeWithSignature("token0()"));
        (bool s1, bytes memory d1) = _addr.staticcall(abi.encodeWithSignature("token1()"));
        if (s0 && s1 && d0.length == 32 && d1.length == 32) {
            return true; // It's a DEX pair contract
        }
        
        (bool s2, ) = _addr.staticcall(abi.encodeWithSignature("factory()"));
        if (s2) return true; // Router contract
        
        (bool s3, ) = _addr.staticcall(abi.encodeWithSignature("getReserves()"));
        if (s3) return true; // Pair contract with reserves
        
        (bool s4, ) = _addr.staticcall(abi.encodeWithSignature("getPair(address,address)", address(0), address(0)));
        if (s4) return true; // DEX factory contract
        
        (bool s5, ) = _addr.staticcall(abi.encodeWithSignature("swap(address,uint256,uint256,uint256,bytes)", address(0), 0, 0, 0, ""));
        if (s5) return true; // Aggregator/swapper contract
        
        (bool s6, ) = _addr.staticcall(abi.encodeWithSignature("supply(address,uint256,address,uint16,uint256)", address(0), 0, address(0), 0, 0));
        if (s6) return true; // Lending protocol contract
        
        (bool s7, ) = _addr.staticcall(abi.encodeWithSignature("deposit(uint256)", 0));
        if (s7) return true; // Yield farm/staking contract
        
        (bool s8, ) = _addr.staticcall(abi.encodeWithSignature("sendToChain(address,uint256,uint256)", address(0), 0, 0));
        if (s8) return true; // Bridge/cross-chain contract
        
        return false;
    }

    function setDevAddress(address _devAddress) external onlyOwner {
        if (_devAddress == address(0)) revert ReflexusAddress();
        address oldDevAddress = devAddress;
        _isExcludedFromFee[devAddress] = false;
        devAddress = _devAddress;
        _isExcludedFromFee[devAddress] = true;
        emit DevAddressChanged(oldDevAddress, _devAddress);
    }

    function excludeFromFee(address account, bool isExcluded) external onlyOwner {
        if (account == address(0)) revert ReflexusAddress();
        _isExcludedFromFee[account] = isExcluded;
        emit FeeExclusionSet(account, isExcluded);
    }

    function getTotalDividendsDistributed() external view returns (uint256) {
        return totalDividendsDistributed;
    }

    function getMagnifiedDividendPerShare() external view returns (uint256) {
        return magnifiedDividendPerShare;
    }
    
    function getCirculatingSupplyPublic() external view returns (uint256) {
        return getCirculatingSupply();
    }

    function getUserDividendInfo(address user) external view returns (
        uint256 balance,
        uint256 userLastDividendPerShare,
        uint256 userAccumulatedDividends,
        uint256 currentDividendPerShare,
        bool isUserContract
    ) {
        return (
            balanceOf(user),
            lastDividendPerShare[user],
            accumulatedDividends[user],
            magnifiedDividendPerShare,
            isContract(user)
        );
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual override returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < subtractedValue) revert InsufficientBalance(); 
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }
}