// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IGauge {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward(address account, address[] memory tokens) external;
    function balanceOf(address account) external view returns (uint256);
}

interface IRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
}

contract AutoCompounderVault is ReentrancyGuard {
    IERC20 public immutable lpToken;
    IGauge public immutable gauge;
    IRouter public immutable router;
    IERC20 public immutable aero;
    address public immutable token0;
    address public immutable token1;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    address public strategist;

    uint256 constant PRECISION = 1e18;

    event Deposited(address indexed user, uint256 lpAmount, uint256 sharesMinted);
    event Withdrawn(address indexed user, uint256 lpAmount, uint256 sharesBurnt);
    event Harvested(address indexed caller, uint256 aeroHarvested, uint256 lpTokensAddedToGauge);
    event StrategistChanged(address indexed oldStrategist, address indexed newStrategist);

    modifier onlyStrategist() {
        require(msg.sender == strategist, "ACV: Not strategist");
        _;
    }

    constructor(
        address _lpToken,
        address _gauge,
        address _router,
        address _aero,
        address _token0,
        address _token1,
        address _strategist
    ) {
        require(_lpToken != address(0), "ACV: Zero address");
        require(_gauge != address(0), "ACV: Zero address");
        require(_router != address(0), "ACV: Zero address");
        require(_aero != address(0), "ACV: Zero address");
        require(_token0 != address(0), "ACV: Zero address");
        require(_token1 != address(0), "ACV: Zero address");
        require(_strategist != address(0), "ACV: Zero address");

        lpToken = IERC20(_lpToken);
        gauge = IGauge(_gauge);
        router = IRouter(_router);
        aero = IERC20(_aero);
        token0 = _token0;
        token1 = _token1;
        strategist = _strategist;
    }

    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "ACV: Amount must be > 0");

        lpToken.transferFrom(msg.sender, address(this), _amount);

        uint256 currentLpBalanceInGauge = gauge.balanceOf(address(this));
        uint256 shares;

        if (totalSupply == 0 || currentLpBalanceInGauge == 0) {
            shares = _amount;
        } else {
            shares = (_amount * totalSupply) / currentLpBalanceInGauge;
        }

        balanceOf[msg.sender] += shares;
        totalSupply += shares;

        lpToken.approve(address(gauge), _amount);
        gauge.deposit(_amount);

        emit Deposited(msg.sender, _amount, shares);
    }

    function withdraw(uint256 _shares) external nonReentrant {
        require(_shares > 0, "ACV: Shares must be > 0");
        require(balanceOf[msg.sender] >= _shares, "ACV: Insufficient shares");

        uint256 currentLpBalanceInGauge = gauge.balanceOf(address(this));
        uint256 lpAmount = (_shares * currentLpBalanceInGauge) / totalSupply;

        balanceOf[msg.sender] -= _shares;
        totalSupply -= _shares;

        gauge.withdraw(lpAmount);
        lpToken.transfer(msg.sender, lpAmount);

        emit Withdrawn(msg.sender, lpAmount, _shares);
    }

    function harvestAndReinvest() external nonReentrant onlyStrategist {
        uint256 aeroBalanceBefore = aero.balanceOf(address(this));
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(aero);

        gauge.getReward(address(this), rewardTokens);

        uint256 aeroHarvested = aero.balanceOf(address(this)) - aeroBalanceBefore;

        if (aeroHarvested == 0) {
            return;
        }

        aero.approve(address(router), aeroHarvested);

        address[] memory path0 = new address[](2);
        path0[0] = address(aero);
        path0[1] = token0;

        address[] memory path1 = new address[](2);
        path1[0] = address(aero);
        path1[1] = token1;

        uint256 amountToSwapForToken0 = aeroHarvested / 2;
        uint256 amountToSwapForToken1 = aeroHarvested - amountToSwapForToken0; // Remaining amount

        uint256 receivedToken0;
        uint256 receivedToken1;

        if (amountToSwapForToken0 > 0) {
            uint[] memory amountsToken0 = router.swapExactTokensForTokens(
                amountToSwapForToken0,
                0,
                path0,
                address(this),
                block.timestamp
            );
            receivedToken0 = amountsToken0[amountsToken0.length - 1];
        }

        if (amountToSwapForToken1 > 0) {
            uint[] memory amountsToken1 = router.swapExactTokensForTokens(
                amountToSwapForToken1,
                0,
                path1,
                address(this),
                block.timestamp
            );
            receivedToken1 = amountsToken1[amountsToken1.length - 1];
        }
        
        if (receivedToken0 > 0) {
            IERC20(token0).approve(address(router), receivedToken0);
        }
        if (receivedToken1 > 0) {
            IERC20(token1).approve(address(router), receivedToken1);
        }

        if (receivedToken0 > 0 && receivedToken1 > 0) {
            (,,uint256 newLpTokens) = router.addLiquidity(
                token0,
                token1,
                receivedToken0,
                receivedToken1,
                0,
                0,
                address(this),
                block.timestamp
            );

            if (newLpTokens > 0) {
                lpToken.approve(address(gauge), newLpTokens);
                gauge.deposit(newLpTokens);
            }
            emit Harvested(msg.sender, aeroHarvested, newLpTokens);
        } else {
            // If one of the tokens wasn't swapped for (e.g. amount was 0),
            // or if addLiquidity was not called because one amount is 0.
            // We still emit harvested event, but newLpTokens might be 0.
            emit Harvested(msg.sender, aeroHarvested, 0);
        }
    }

    function setStrategist(address _newStrategist) external onlyStrategist {
        require(_newStrategist != address(0), "ACV: Zero address");
        address oldStrategist = strategist;
        strategist = _newStrategist;
        emit StrategistChanged(oldStrategist, _newStrategist);
    }

    function lpBalanceInGauge() external view returns (uint256) {
        return gauge.balanceOf(address(this));
    }

    function lpTokensPerShare() external view returns (uint256) {
        if (totalSupply == 0) {
            return PRECISION; // Or some other sensible default, like 0 or 1e18
        }
        return (gauge.balanceOf(address(this)) * PRECISION) / totalSupply;
    }
}
