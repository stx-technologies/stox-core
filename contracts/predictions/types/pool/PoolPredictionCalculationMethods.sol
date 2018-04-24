pragma solidity ^0.4.23;

/*
    @title PoolPredictionCalculationMethods contract - holds an enum of calculation options
*/
contract PoolPredictionCalculationMethods {

    enum PoolCalculationMethod {
        breakEven, //the user gets what he placed, no matter win or lose
        relative   //the user gets a prize only for a winning outcome, and with respect to other placements
    }
}
