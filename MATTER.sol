// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./Include.sol";

contract MATTER is ERC20UpgradeSafe, Configurable {
	function __MATTER_init(address governor_, address offering_, address public_, address team_, address fund_, address mine_, address liquidity_) external initializer {
        __Context_init_unchained();
		__ERC20_init_unchained("Antimatter.Finance Governance Token", "MATTER");
		__Governable_init_unchained(governor_);
		__MATTER_init_unchained(offering_, public_, team_, fund_, mine_, liquidity_);
	}
	
	function __MATTER_init_unchained(address offering_, address public_, address team_, address fund_, address mine_, address liquidity_) public governance {
		_mint(offering_,    24_000_000 * 10 ** uint256(decimals()));
		_mint(public_,       1_000_000 * 10 ** uint256(decimals()));
		_mint(team_,        10_000_000 * 10 ** uint256(decimals()));
		_mint(fund_,        10_000_000 * 10 ** uint256(decimals()));
		_mint(mine_,        50_000_000 * 10 ** uint256(decimals()));
		_mint(liquidity_,    5_000_000 * 10 ** uint256(decimals()));
	}
	
}


contract Offering is Configurable {
	using SafeMath for uint;
	using SafeERC20 for IERC20;
	
	bytes32 internal constant _quota_      = 'quota';
	bytes32 internal constant _allowlist_  = 'allowlist';
	bytes32 internal constant _isSeed_     = 'isSeed';
	
	IERC20 public token;
	IERC20 public currency;
	uint public price;
	address public vault;
	uint public begin;
	uint public span;
	mapping (address => uint) public offeredOf;
	
	function __Offering_init(address governor_, address _token, address _currency, uint _price, uint _quota, address _vault, uint _begin, uint _span) external initializer {
		__Governable_init_unchained(governor_);
		__Offering_init_unchained(_token, _currency, _price, _quota, _vault, _begin, _span);
	}
	
	function __Offering_init_unchained(address _token, address _currency, uint _price, uint _quota, address _vault, uint _begin, uint _span) public governance {
		token = IERC20(_token);
		currency = IERC20(_currency);
		price = _price;
		vault = _vault;
		begin = _begin;
		span = _span;
		config[_quota_] = _quota;
	}
	
    function addAllowlist(address addr, uint amount, bool isSeed) public governance {
        _setConfig(_allowlist_, addr, amount);
        if(isSeed)
            _setConfig(_isSeed_, addr, 1);
    }
    
    function addAllowlists(address[] memory addrs, uint[] memory amounts, bool isSeed) public {
        for(uint i=0; i<addrs.length; i++)
            addAllowlist(addrs[i], amounts[i], isSeed);
    }

	function offer() external {
		require(now >= begin, 'Not begin');
		if(now > begin.add(span))
			if(token.balanceOf(address(this)) > 0)
				token.safeTransfer(mine, token.balanceOf(address(this)));
			else
				revert('offer over');
		require(offeredOf[msg.sender] < config[_quota_], 'out of quota');
		vol = Math.min(Math.min(vol, config[_quota_].sub(offeredOf[msg.sender])), token.balanceOf(address(this)));
		offeredOf[msg.sender] = offeredOf[msg.sender].add(vol);
		uint amt = vol.mul(price).div(1e18);
		currency.safeTransferFrom(msg.sender, address(this), amt);
		currency.approve(vault, amt);
		IVault(vault).receiveAEthFrom(address(this), amt);
		token.safeTransfer(msg.sender, vol);
	}
}

contract Timelock is Configurable {
	using SafeMath for uint;
	using SafeERC20 for IERC20;
	
	IERC20 public token;
	address public recipient;
	uint public begin;
	uint public span;
	uint public times;
	uint public total;
	
	function start(address _token, address _recipient, uint _begin, uint _span, uint _times) external governance {
		require(address(token) == address(0), 'already start');
		token = IERC20(_token);
		recipient = _recipient;
		begin = _begin;
		span = _span;
		times = _times;
		total = token.balanceOf(address(this));
	}

    function unlockCapacity() public view returns (uint) {
       if(begin == 0 || now < begin)
            return 0;
            
        for(uint i=1; i<=times; i++)
            if(now < span.mul(i).div(times).add(begin))
                return token.balanceOf(address(this)).sub(total.mul(times.sub(i)).div(times));
                
        return token.balanceOf(address(this));
    }
    
    function unlock() public {
        token.safeTransfer(recipient, unlockCapacity());
    }
    
    fallback() external {
        unlock();
    }
}
