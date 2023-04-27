import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:walletconnect_dart/walletconnect_dart.dart';

class WalletConnection {
  // CREATING A CONNECT VARAIBLE WITH YOUR DETAILS
  var connector = WalletConnect(
      bridge: 'https://bridge.walletconnect.org',
      clientMeta: const PeerMeta(
          name: 'NAME', // NAME OF YOUR APP TO DISPLAY
          description: 'An app for converting pictures to NFT', // DESCRIPTION
          url:
              'https://exaple.io', // TODO : PUT YOUR OWN DOMAIN WAHT YOU WANNA DISPLY TO USER WHEN THE CONNECTION POP UP APPEARS
          icons: [
            'https://files.gitbook.com/v0/b/gitbook-legacy-files/o/spaces%2F-LJJeCjcLrr53DcT1Ml7%2Favatar.png?alt=media'
          ]));

  // SessionStatus _session;
  var _uri;

  // LOGIN INTO METAMASK WALLET
  loginUsingMetamask() async {
    print("connecting wallet :::  ");
    //print("wallet session === $_session");
    var currentsession = connector.bridgeConnected;
    if (!connector.connected && currentsession) {
      print("wallet connecting connected :::${connector.connected}  ");
      //connector.close();
      try {
        // creating a wallet session to connect
        var session = await connector.createSession(onDisplayUri: (uri) async {
          _uri = uri;
          var usriParse = Uri.parse(uri);
          try {
            // launching the url to external application in metamask to connect your wallet
            await launchUrl(usriParse, mode: LaunchMode.externalApplication);
          } catch (e) {
            print("wallet not found error ${e}");
          }
        });
        print("wallet session 2 : $session");

      ;
      } catch (exp) {
        print("wallet error :$exp");
      }
    }
  }

  /// KILL THE CURRENT SESSION
  killsession() {
    try {
      connector.killSession();
    } catch (e) {
      print("wallet disconnect error ${e}");
    }
  }
}
