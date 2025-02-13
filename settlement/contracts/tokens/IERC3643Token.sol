pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC3643 is IERC20 {
    function canTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external view returns (bool, uint256, bytes32);
    
    function transferWithData(
        address _to,
        uint256 _amount,
        bytes calldata _data
    ) external returns (bool);
    
    function transferFromWithData(
        address _from,
        address _to,
        uint256 _amount,
        bytes calldata _data
    ) external returns (bool);
}
