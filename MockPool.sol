// contracts/MockPool.sol
pragma solidity ^0.8.20;

contract MockPool {
    function swap(address token, address to, uint256 amount) external {
        IERC20(token).transfer(to, amount);
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}
