 CargoLock  Smart Escrow System for Cargo Delivery

A Stacks blockchain smart contract that automatically releases payments when cargo reaches verified GPS coordinates and meets specified environmental conditions (temperature, humidity, shock sensors).

 Overview

CargoLock revolutionizes cargo delivery payments by providing a trustless, automated escrow system that integrates with realworld IoT sensors and GPS tracking. The smart contract eliminates manual payment processing and disputes by automatically releasing funds only when all delivery conditions are verifiably met.

 Features

 Core Functionality
 Smart Escrow Creation: Shippers create escrows with customizable delivery conditions
 GPS Verification: Automatic location verification using coordinate proximity checking
 Environmental Monitoring: Temperature, humidity, and shock level validation
 Automated Payment Release: Funds released automatically when all conditions are met
 Oracle Integration: Authorized oracles provide verified sensor data
 Shipment Lifecycle: Complete tracking from creation to delivery

 Condition Parameters
 GPS Coordinates: Target latitude and longitude with proximity tolerance
 Temperature Range: Minimum and maximum temperature thresholds
 Humidity Control: Maximum humidity level monitoring
 Shock Protection: Maximum Gforce threshold for fragile cargo
 Custom Tolerances: Flexible condition parameters per shipment

 Security Features
 Authorized Oracles: Only verified oracles can confirm deliveries
 Input Validation: Comprehensive validation of all user inputs and sensor data
 Escrow Protection: Funds held securely until conditions are met
 Cancellation Rights: Shippers can cancel before transit begins

 Technical Details

 Shipment Status Flow
1. Created  Escrow established, payment locked
2. In Transit  Carrier confirmed pickup
3. Delivered  Conditions met, payment released
4. Cancelled  Shipment cancelled, funds refunded

 Condition Validation
 GPS Proximity: Manhattan distance calculation with 0.5 degree tolerance
 Temperature: Kelvin scale (233K to 373K / 40°C to 100°C)
 Humidity: Percentage scale (0100%)
 Shock: Gforce measurement (01000G)

 Smart Contract Functions

 Public Functions
 createshipment(...)  Create new escrow with delivery conditions
 startshipment(shipmentid)  Carrier confirms pickup
 confirmdelivery(...)  Oracle confirms delivery with sensor data
 cancelshipment(shipmentid)  Cancel shipment and refund
 authorizeoracle(oracle)  Admin function to authorize oracles
 revokeoracle(oracle)  Admin function to revoke oracle access

 ReadOnly Functions
 getshipment(shipmentid)  Retrieve shipment details
 getdeliveryconfirmation(shipmentid)  Get delivery sensor data
 isoracleauthorized(oracle)  Check oracle authorization status
 getshipmentstatus(shipmentid)  Get current shipment status
 checkdeliveryconditions(shipmentid)  Validate all delivery conditions
 getglobalstats()  Platform statistics and metrics

 Usage Example

 1. Create Shipment Escrow
clarity
(contractcall? .cargolock createshipment
 SP2CARRIER... ;; carrier principal
 SP2RECEIVER... ;; receiver principal
  u4000000 ;; target latitude  100000
  u7400000 ;; target longitude  100000
  u273 ;; min temp (0°C in Kelvin)
  u277 ;; max temp (4°C in Kelvin)
  u80 ;; max humidity (80%)
  u50 ;; max shock (50G)
  u1000000) ;; payment amount (1M STX)


 Oracle Integration

CargoLock relies on authorized oracles to provide verified sensor data:

 GPS Tracking: Realtime location updates
 Temperature Sensors: Continuous temperature monitoring
 Humidity Sensors: Environmental condition tracking
 Shock Sensors: Impact and vibration detection
 Timestamp Verification: Delivery time confirmation


 Error Codes

 u100  Unauthorized access
 u101  Shipment not found
 u102  Invalid amount
 u103  Shipment already exists
 u104  Invalid input parameters
 u105  Shipment already completed
 u106  Delivery conditions not met
 u107  Insufficient funds
 u108  Invalid shipment status


 Use Cases

 Cold Chain Logistics

 Pharmaceutical shipments requiring temperature control
 Fresh food delivery with humidity monitoring
 Vaccine distribution with strict environmental requirements


 HighValue Cargo

 Electronics with shock protection requirements
 Artwork and antiques with environmental controls
 Precision instruments requiring stable conditions


 International Shipping

 Crossborder deliveries with GPS verification
 Customscleared cargo with location confirmation
 Timesensitive deliveries with automated processing


 Benefits

 For Shippers

 Automated Payments: No manual processing required
 Condition Guarantee: Payment only released when conditions are met
 Dispute Reduction: Transparent, verifiable delivery confirmation
 Cost Efficiency: Reduced administrative overhead


 For Carriers

 Guaranteed Payment: Automatic release upon successful delivery
 Clear Requirements: Transparent delivery conditions
 Performance Incentives: Rewards for meeting all conditions
 Trust Building: Blockchainverified delivery records


 For Receivers

 Quality Assurance: Guaranteed condition compliance
 Delivery Verification: Immutable delivery records
 Transparency: Realtime condition monitoring
 Accountability: Clear responsibility chain


 Development

Built for Stacks blockchain using Clarity smart contract language. The contract passes clarinet check without errors and implements comprehensive input validation and security measures.

 License

MIT License  See LICENSE file for details