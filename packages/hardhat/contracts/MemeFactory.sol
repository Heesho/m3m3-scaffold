// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Meme.sol";

contract MemeFactory is Ownable {

    /*----------  CONSTANTS  --------------------------------------------*/

    uint256 public constant NAME_MAX_LENGTH = 80;
    uint256 public constant SYMBOL_MAX_LENGTH = 8;

    /*----------  STATE VARIABLES  --------------------------------------*/
    
    address public immutable base;
    address public treasury;

    uint256 public minAmountIn = 100000000000000000; // 0.1 ETH
    uint256 count = 1;
    mapping(uint256=>address) public index_Meme;
    mapping(address=>uint256) public meme_Index;
    mapping(string=>uint256) public symbol_Index;

    /*----------  ERRORS ------------------------------------------------*/

    error MemeFactory__NameRequired();
    error MemeFactory__SymbolRequired();
    error MemeFactory__SymbolExists();
    error MemeFactory__NameLimitExceeded();
    error MemeFactory__SymbolLimitExceeded();
    error MemeFactory__InsufficientAmountIn();

    /*----------  EVENTS ------------------------------------------------*/
    
    event MemeFactory__MemeCreated(uint256 index, address meme);
    event MemeFactory__TreasuryUpdated(address treasury);

    /*----------  MODIFIERS  --------------------------------------------*/

    /*----------  FUNCTIONS  --------------------------------------------*/

    constructor(address _base, address _treasury) {
        base = _base;
        treasury = _treasury;
    }
        
    function createMeme(
        string memory name,
        string memory symbol,
        string memory uri,
        uint256 amountIn
    ) external returns (address) {
        if (amountIn < minAmountIn) revert MemeFactory__InsufficientAmountIn();
        if (symbol_Index[symbol] != 0) revert MemeFactory__SymbolExists();
        if (bytes(name).length == 0) revert MemeFactory__NameRequired();
        if (bytes(symbol).length == 0) revert MemeFactory__SymbolRequired();
        if (bytes(name).length > NAME_MAX_LENGTH) revert MemeFactory__NameLimitExceeded();
        if (bytes(symbol).length > SYMBOL_MAX_LENGTH) revert MemeFactory__SymbolLimitExceeded();

        address meme = address(new Meme(name, symbol, uri, base));
        index_Meme[count] = meme;
        meme_Index[meme] = count;
        symbol_Index[symbol] = count;

        emit MemeFactory__MemeCreated(count, meme);
        count++;

        IERC20(base).transferFrom(msg.sender, address(this), amountIn);
        IERC20(base).approve(meme, amountIn);
        Meme(meme).buy(amountIn, 0, 0, msg.sender, address(0));

        return meme;
    }

    /*----------  RESTRICTED FUNCTIONS  ---------------------------------*/

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    function setMinAmountIn(uint256 _minAmountIn) external onlyOwner {
        minAmountIn = _minAmountIn;
    }

    /*----------  VIEW FUNCTIONS  ---------------------------------------*/

    function getMemeCount() external view returns (uint256) {
        return count - 1;
    }

    function getMemeByIndex(uint256 index) external view returns (address) {
        return index_Meme[index];
    }

    function getIndexByMeme(address meme) external view returns (uint256) {
        return meme_Index[meme];
    }

    function getIndexBySymbol(string memory symbol) external view returns (uint256) {
        return symbol_Index[symbol];
    }

}