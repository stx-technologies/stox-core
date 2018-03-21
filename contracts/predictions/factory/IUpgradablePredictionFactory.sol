pragma solidity ^0.4.18;
import "../../token/IERC20Token.sol";
import "../types/pool/PoolPredictionPrizeDistribution.sol";
import "../types/pool/PoolPredictionPrizeLib.sol";

contract IUpgradablePredictionFactory {
    function createPoolPrediction(address _oracle, 
                                    uint _predictionEndTimeSeconds, 
                                    uint _optionBuyingEndTimeSeconds, 
                                    string _name, IERC20Token _stox, 
                                    PoolPredictionPrizeLib.CalculationMethod _calculationMethod) 
                                    public;
    event PoolPredictionCreated(address indexed _creator, address indexed _newPrediction);
}