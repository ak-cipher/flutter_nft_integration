import 'dart:convert';
import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:web3dart/web3dart.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class NFTContractService extends GetxController {
  late Web3Client polygonClient;

  http.Client httpClient = http.Client();

  Mode mode = Mode.none; // or shownfts or mint

  Map<String, StateMutability> _mutabilityNames = {
    'pure': StateMutability.pure,
    'view': StateMutability.view,
    'nonpayable': StateMutability.nonPayable,
    'payable': StateMutability.payable,
  };
  Map<String, ContractFunctionType> _functionTypeNames = {
    'function': ContractFunctionType.function,
    'constructor': ContractFunctionType.constructor,
    'fallback': ContractFunctionType.fallback,
  };

  @override
  void onInit() async {
    final ALCHEMY_KEY = dotenv.env['ALCHEMY_KEY_TEST'];  // Defined in the .env file getting the rpc url with project id
    super.onInit();
    httpClient = http.Client();
    polygonClient = Web3Client(ALCHEMY_KEY!, httpClient);
  }

  Future<DeployedContract> getContract() async {
    final CONTRACT_NAME = dotenv.env['CONTRACT_NAME'];
    print("nft contract name ${CONTRACT_NAME}");
    final CONTRACT_ADDRESS = dotenv.env['CONTRACT_ADDRESS'];
    print("nft contract adddress ${CONTRACT_ADDRESS}");

    String abi =
        await rootBundle.loadString("assets/contract.json"); //TODO update with your own contract file name
    //log("abi data ${abi}");
    print("abi");
    var data = json.decode(abi);
    log("abi data ${data["abi"]}");

    var dataabi = ContractAbifromJson(data["abi"], CONTRACT_NAME!);
    print("abi done ${dataabi}");
    DeployedContract contract = DeployedContract(
      // ContractAbi.fromJson(abi, CONTRACT_NAME!),
      dataabi,
      EthereumAddress.fromHex(CONTRACT_ADDRESS!),
    );
    print("nft contract ${contract}");
    return contract;
  }


  // GETTING THE ABI FROM THE CONTRACT 
  ContractAbifromJson(List jsonData, String name) {
    //final data = json.decode(jsonData);

    final functions = <ContractFunction>[];

    final events = <ContractEvent>[];

    for (final element in jsonData) {
      final type = element['type'] as String;
      final name = (element['name'] as String?) ?? '';

      if (type == 'event') {
        final anonymous = element['anonymous'] as bool;
        final components = <EventComponent>[];

        for (final entry in element['inputs']) {
          components.add(
            EventComponent(
              _parseParam(entry as Map),
              entry['indexed'] as bool,
            ),
          );
        }

        events.add(ContractEvent(anonymous, name, components));
        continue;
      }

      final mutability = _mutabilityNames[element['stateMutability']];
      final parsedType = _functionTypeNames[element['type']];
      if (parsedType == null) continue;

      final inputs = _parseParams(element['inputs'] as List?);
      final outputs = _parseParams(element['outputs'] as List?);

      functions.add(
        ContractFunction(
          name,
          inputs,
          outputs: outputs,
          type: parsedType,
          mutability: mutability ?? StateMutability.nonPayable,
        ),
      );
    }

    print("nft name ${name}");
    log("nft functions ${functions.map((e) => e.name).toList()}");
    print("nft events ${events[0].name}");

    return ContractAbi(name, functions, events);
  }

  static List<FunctionParameter> _parseParams(List? data) {
    if (data == null || data.isEmpty) return [];

    final elements = <FunctionParameter>[];
    for (final entry in data) {
      elements.add(_parseParam(entry as Map));
    }

    return elements;
  }

  static FunctionParameter _parseParam(Map entry) {
    final name = entry['name'] as String;
    final typeName = entry['type'] as String;

    if (typeName.contains('tuple')) {
      final components = entry['components'] as List;
      return _parseTuple(name, typeName, _parseParams(components));
    } else {
      final type = parseAbiType(entry['type'] as String);
      return FunctionParameter(name, type);
    }
  }

  static CompositeFunctionParameter _parseTuple(
    String name,
    String typeName,
    List<FunctionParameter> components,
  ) {
    final RegExp array = RegExp(r'^(.*)\[(\d*)\]$');

    // The type will have the form tuple[3][]...[1], where the indices after the
    // tuple indicate that the type is part of an array.
    assert(
      RegExp(r'^tuple(?:\[\d*\])*$').hasMatch(typeName),
      '$typeName is an invalid tuple type',
    );

    final arrayLengths = <int?>[];
    var remainingName = typeName;

    while (remainingName != 'tuple') {
      final arrayMatch = array.firstMatch(remainingName)!;
      remainingName = arrayMatch.group(1)!;

      final insideSquareBrackets = arrayMatch.group(2)!;
      if (insideSquareBrackets.isEmpty) {
        arrayLengths.insert(0, null);
      } else {
        arrayLengths.insert(0, int.parse(insideSquareBrackets));
      }
    }

    return CompositeFunctionParameter(name, components, arrayLengths);
  }


  // QUERY FUNCTION TO CALL DIIFREENT FUCNTION FROM THE CONTRACT 
  Future<List<dynamic>> query(String functionName, List<dynamic> args) async {
    DeployedContract contract = await getContract(); // GETTING THE CONTRACT INFORMATION 
    print("nft contract fetched ");
    ContractFunction function = contract.function(functionName); // GETTING ALL THE LISTED FUNCTION AVAILABLE IN THE CONTRACT
    print("nft function fetched ${functionName}");

    // CALLING THE FUCNTION USING POLYGON CLIENT NETWORK AND PASSING THE ARGUS NECCESSARY FOR EACH FUNCTION
    List<dynamic> result = await polygonClient.call(
        contract: contract, function: function, params: args);
    print("nft polygon client call");
    return result;
  }

  Future<Map> getImageFromToken(int token) async {
   
    String session = "user wallet connect id"; //TODO : REPLACE WITH USER WALLET ID
    print("wallet id ${session}");
    // GETTING THE ETHEREUM ADDRES FORM WALLET ID
    EthereumAddress address = EthereumAddress.fromHex(session);

    // CALLING THE BALANCE OF FUNCTION FROM THE CONTRACT TO GET THE NUMBER OF TOKENS A USER HAVE OF NFT
    List<dynamic> token1 = await query('balanceOf', [address]);
    print("wallet token ${token1[0]}");

    List<dynamic> result = await query('tokenURI', [token1[0]]);
    String json = result[0]; //TODO change name, json is really an URL, not json
    print("image json ${json}");
    Uint8List png = await getImageFromJson(json);  
    return {"png": png, "json": json};
  }

  Future<Uint8List> getImageFromJson(String json) async {
    final JSON_CID = dotenv.env['JSON_CID'];
    final IMAGES_CID = dotenv.env['IMAGES_CID'];
    String url = json
        .toString()
        .replaceFirst(r'ipfs://', r'https://ipfs.io/ipfs/')
        .replaceFirst(JSON_CID!, IMAGES_CID!)
        .replaceFirst('.json', '.png');
    var resp = await httpClient.get(Uri.parse(url));
    // TODO Add error checking - if(resp.statusCode!= 200) etc
    return Uint8List.fromList(resp.body.codeUnits);
  }
}

enum Mode { none, shownfts, mint }
