pragma solidity ^0.8.19;
import "@openzepplin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzepplin/contracts/security/ReentrancyGuard.sol";

contract Vault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address => mapping(address => uint256)) private balance;
    address public constant ETH_ADDRESS = address(0);

    event Deposit(address indexed user,address indexed token,uint256 amount);
    event Withdraw(address indexed user,address indexed token,uint256 amount);

    function depositEth() external payable{
        require(msg.value>0,"not enough ETH");
        balance[msg.sender][ETH_ADDRESS]+=msg.value;
        emit Deposit(msg.sender,ETH_ADDRESS,msg.value);
    }

    function withdrawEth(uint256 amount) external{
        require(balance[msg.sender][ETH_ADDRESS] >= amount, "Insufficient balance");
        require(amount > 0,"not enough ETH");

        balance[msg.sender][ETH_ADDRESS] -= amount;

        (bool success,)=msg.sender.call{value:amount}("");
        require(success,"Transfer failed");

        emit Withdraw(msg.sender,ETH_ADDRESS,amount);
    }
    
    function getBalance(address user)  external view returns(uint256 ){
        return balance[user][ETH_ADDRESS];
        }

    function getMyBalance() external view returns(uint256 ){
        return balance[msg.sender][ETH_ADDRESS];
    }
    //存token
    function depositToken(address token, uint256 amount) external nonReentrant {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");
   
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        balances[msg.sender][token] += amount;
        
        emit Deposit(msg.sender, token, amount);
    }
    //取token
    function withdrawToken(address token, uint256 amount) external nonReentrant {
        require(token != address(0), "Invalid token address");
        require(balances[msg.sender][token] >= amount, "Insufficient balance");
        require(amount > 0, "Amount must be greater than 0");
    

        balances[msg.sender][token] -= amount;
        
        IERC20(token).safeTransfer(msg.sender, amount);
        
        emit Withdraw(msg.sender, token, amount);
    }
        

}