// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IMemeFactory {
    function treasury() external view returns (address);
}

contract MemeFees {

    address internal immutable base;
    address internal immutable meme;

    constructor(address _base) {
        meme = msg.sender;
        base = _base;
    }

    function claimFeesFor(address recipient, uint amountBase) external {
        require(msg.sender == meme);
        if (amountBase > 0) IERC20(base).transfer(recipient, amountBase);
    }

}

contract Meme is ERC20, ERC20Permit, ERC20Votes, ReentrancyGuard {

    /*----------  CONSTANTS  --------------------------------------------*/

    uint256 public constant PRECISION = 1e18;
    uint256 public constant RESERVE_VIRTUAL_BASE = 100 * PRECISION;
    uint256 public constant INITIAL_SUPPLY = 1000000 * PRECISION;
    uint256 public constant FEE = 100;
    uint256 public constant PROTOCOL_FEE = 2500;
    uint256 public constant PROVIDER_FEE = 2500;
    uint256 public constant DIVISOR = 10000;
    uint256 public constant STATUS_MAX_LENGTH = 280;
    uint256 public constant STATUS_UPDATE_FEE = 10 * PRECISION;

    /*----------  STATE VARIABLES  --------------------------------------*/

    address public immutable base;
    address public immutable fees;
    address public immutable factory;

    uint256 public maxSupply = INITIAL_SUPPLY;

    // bonding curve state
    uint256 public reserveBase = 0;
    uint256 public reserveMeme = INITIAL_SUPPLY;

    // fees state
    uint256 public totalFeesBase;
    uint256 public indexBase;
    mapping(address => uint256) public supplyIndexBase;
    mapping(address => uint256) public claimableBase;

    address public statusHolder;
    string public uri;
    string public status;

    /*----------  ERRORS ------------------------------------------------*/

    error Meme__ZeroInput();
    error Meme__Expired();
    error Meme__SlippageToleranceExceeded();
    error Meme__StatusLimitExceeded();
    error Meme__StatusRequired();

    /*----------  EVENTS ------------------------------------------------*/

    event Meme__Buy(address indexed sender, address to, uint256 amountIn, uint256 amountOut);
    event Meme__Sell(address indexed sender, address to, uint256 amountIn, uint256 amountOut);
    event Meme__Fees(address indexed sender, uint256 amountBase, uint256 amountMeme);
    event Meme__Claim(address indexed sender, uint256 amountBase);
    event Meme__StatusUpated(address indexed sender, string status);

    /*----------  MODIFIERS  --------------------------------------------*/

    modifier notExpired(uint256 expireTimestamp) {
        if (expireTimestamp != 0 && expireTimestamp < block.timestamp) revert Meme__Expired();
        _;
    }

    modifier notZeroInput(uint256 _amount) {
        if (_amount == 0) revert Meme__ZeroInput();
        _;
    }

    /*----------  FUNCTIONS  --------------------------------------------*/

    constructor(string memory _name, string memory _symbol, string memory _uri, address _base)
        ERC20(_name, _symbol)
        ERC20Permit(_name)
    {
        factory = msg.sender;
        base = _base;
        fees = address(new MemeFees(_base));

        uri = _uri;
        status = "Bm, would you like to say henlo?";
    }

    function buy(uint256 amountIn, uint256 minAmountOut, uint256 expireTimestamp, address to, address provider) 
        external 
        nonReentrant
        notZeroInput(amountIn)
        notExpired(expireTimestamp) 
    {
        uint256 feeBase = amountIn * FEE / DIVISOR;
        uint256 newReserveBase = RESERVE_VIRTUAL_BASE + reserveBase + amountIn - feeBase;
        uint256 newReserveMeme = (RESERVE_VIRTUAL_BASE + reserveBase) * reserveMeme / newReserveBase;
        uint256 amountOut = reserveMeme - newReserveMeme;

        if (amountOut < minAmountOut) revert Meme__SlippageToleranceExceeded();

        reserveBase = newReserveBase - RESERVE_VIRTUAL_BASE;
        reserveMeme = newReserveMeme;

        emit Meme__Buy(msg.sender, to, amountIn, amountOut);

        IERC20(base).transferFrom(msg.sender, address(this), amountIn);
        if (provider != address(0)) {
            uint256 providerFee = feeBase * PROVIDER_FEE / DIVISOR;
            IERC20(base).transfer(provider, providerFee);
            uint256 protocolFee = feeBase * PROTOCOL_FEE / DIVISOR;
            IERC20(base).transfer(IMemeFactory(factory).treasury(), protocolFee);
            feeBase -= (providerFee + protocolFee);
        } else {
            uint256 protocolFee = feeBase * PROTOCOL_FEE / DIVISOR;
            IERC20(base).transfer(IMemeFactory(factory).treasury(), protocolFee);
            feeBase -= protocolFee;
        }
        _mint(to, amountOut);
        _updateBase(feeBase); 
    }

    function sell(uint256 amountIn, uint256 minAmountOut, uint256 expireTimestamp, address to) 
        external 
        nonReentrant
        notZeroInput(amountIn)
        notExpired(expireTimestamp) 
    {
        uint256 feeMeme = amountIn * FEE / DIVISOR;
        uint256 newReserveMeme = reserveMeme + amountIn - feeMeme;
        uint256 newReserveBase = (RESERVE_VIRTUAL_BASE + reserveBase) * reserveMeme / newReserveMeme;
        uint256 amountOut = RESERVE_VIRTUAL_BASE + reserveBase - newReserveBase;

        if (amountOut < minAmountOut) revert Meme__SlippageToleranceExceeded();

        reserveBase = newReserveBase - RESERVE_VIRTUAL_BASE;
        reserveMeme = newReserveMeme;

        emit Meme__Sell(msg.sender, to, amountIn, amountOut);

        _burn(msg.sender, amountIn - feeMeme);
        if (statusHolder != address(0)) {
            transfer(statusHolder, feeMeme / 2);
            feeMeme -= feeMeme / 2;
        }
        burnMeme(feeMeme);
        IERC20(base).transfer(to, amountOut);
    }

    function claimFees(address account) 
        external 
        returns (uint256 claimedBase) 
    {
        _updateFor(account);

        claimedBase = claimableBase[account];

        if (claimedBase > 0) {
            claimableBase[account] = 0;

            MemeFees(fees).claimFeesFor(account, claimedBase);

            emit Meme__Claim(account, claimedBase);
        }
    }

    function updateStatus(address account, string memory _status) 
        external 
    {
        if (bytes(_status).length == 0) revert Meme__StatusRequired();
        if (bytes(_status).length > STATUS_MAX_LENGTH) revert Meme__StatusLimitExceeded();
        burnMeme(STATUS_UPDATE_FEE);
        status = _status;
        statusHolder = account;
        emit Meme__StatusUpated(account, _status);
    }

    function burnMeme(uint256 amount) 
        public 
        notZeroInput(amount)
    {
        maxSupply -= amount;
        _burn(msg.sender, amount);
    }

    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/

    function _updateBase(uint256 amount) internal {
        IERC20(base).transfer(fees, amount);
        totalFeesBase += amount;
        uint256 _ratio = amount * 1e18 / totalSupply();
        if (_ratio > 0) {
            indexBase += _ratio;
        }
        emit Meme__Fees(msg.sender, amount, 0);
    }
    
    function _updateFor(address recipient) internal {
        uint256 _supplied = balanceOf(recipient);
        if (_supplied > 0) {
            uint256 _supplyIndexBase = supplyIndexBase[recipient];
            uint256 _indexBase = indexBase; 
            supplyIndexBase[recipient] = _indexBase;
            uint256 _deltaBase = _indexBase - _supplyIndexBase;
            if (_deltaBase > 0) {
                uint256 _share = _supplied * _deltaBase / 1e18;
                claimableBase[recipient] += _share;
            }
        } else {
            supplyIndexBase[recipient] = indexBase; 
        }
    }

    /*----------  FUNCTION OVERRIDES  -----------------------------------*/

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20)
    {
        super._beforeTokenTransfer(from, to, amount);
        _updateFor(from);
        _updateFor(to);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

    /*----------  VIEW FUNCTIONS  ---------------------------------------*/

    function getMarketPrice() external view returns (uint256) {
        return ((RESERVE_VIRTUAL_BASE + reserveBase) * PRECISION) / reserveMeme;
    }

    function getFloorPrice() external view returns (uint256) {
        return (RESERVE_VIRTUAL_BASE * PRECISION) / maxSupply;
    }

}
