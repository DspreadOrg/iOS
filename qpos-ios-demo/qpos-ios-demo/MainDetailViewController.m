//
//  MainDetailViewController.m
//  qpos-ios-demo
//
//  Created by Robin on 11/19/13.
//  Copyright (c) 2013 Robin. All rights reserved.
//
#import <MediaPlayer/MPMusicPlayerController.h>
#import "MainDetailViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import "QPOSUtil.h"
#import "GDataXMLNode.h"
#import "TagApp.h"
#import "TagCapk.h"
#import "TLVParser.h"
#import <CommonCrypto/CommonCrypto.h>

typedef enum : NSUInteger {
    EMVAppXMl,
    EMVCapkXMl,
} EMVXML;

@interface MainDetailViewController ()
@property (nonatomic,copy)NSString *terminalTime;
@property (nonatomic,copy)NSString *currencyCode;
@property (weak, nonatomic) IBOutlet UILabel *labSDK;
@property (weak, nonatomic) IBOutlet UIButton *btnStart;
@property (weak, nonatomic) IBOutlet UIButton *btnGetPosId;
@property (weak, nonatomic) IBOutlet UIButton *btnGetPosInfo;
@property (weak, nonatomic) IBOutlet UIButton *btnDisconnect;
@property (weak, nonatomic) IBOutlet UIButton *btnUpdateEMV;
@property (nonatomic,assign)BOOL updateFWFlag;
@property (nonatomic,strong)NSDictionary *pinDataDict;

@end

@implementation MainDetailViewController{
    QPOSService *pos;
    PosType     mPosType;
    dispatch_queue_t self_queue;
    TransactionType mTransType;
    NSString *msgStr;
}

@synthesize bluetoothAddress;
@synthesize amount;
@synthesize cashbackAmount;

#pragma mart - sdk delegate

- (void)configureView{
    // Update the user interface for the detail item.
    if (self.detailItem) {
        NSString *aStr = [self.detailItem description];
        self.bluetoothAddress = aStr;
    }
}

- (void)viewDidLoad{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self configureView];
    self.btnDisconnect.layer.cornerRadius = 10;
    self.btnStart.layer.cornerRadius = 10;
    self.btnGetPosId.layer.cornerRadius = 10;
    self.btnGetPosInfo.layer.cornerRadius = 10;
    self.btnResetPos.layer.cornerRadius = 10;
    self.btnUpdateEMV.layer.cornerRadius = 10;
    self.pinDataDict = [NSDictionary dictionary];
    if (nil == pos) {
        pos = [QPOSService sharedInstance];
    }
    [pos setDelegate:self];
    self.labSDK.text =[@"V" stringByAppendingString:[pos getSdkVersion]];
    
    [pos setQueue:nil];
    if (_detailItem == nil || [_detailItem  isEqual: @""]) {
        self.bluetoothAddress = @"audioType";
    }
    if([self.bluetoothAddress isEqualToString:@"audioType"]){
        [self.btnDisconnect setHidden:YES];
        mPosType = PosType_AUDIO;
        [pos setPosType:PosType_AUDIO];
        [pos startAudio];
        MPMusicPlayerController *mpc = [MPMusicPlayerController applicationMusicPlayer];
        mpc.volume = .7;
    }else{
        mPosType = PosType_BLUETOOTH_2mode;
        [pos setPosType:PosType_BLUETOOTH_2mode];
        self.textViewLog.text = NSLocalizedString(@"connecting bluetooth...", nil);
        [pos connectBT:self.bluetoothAddress];
    }
}

-(void)viewDidDisappear:(BOOL)animated{
    if (mPosType == PosType_AUDIO) {
        NSLog(@"viewDidDisappear stop audio");
        [pos stopAudio];
    }else if(mPosType == PosType_BLUETOOTH || mPosType == PosType_BLUETOOTH_new || mPosType == PosType_BLUETOOTH_2mode){
        NSLog(@"viewDidDisappear disconnect buluetooth");
        [pos disconnectBT];
    }
}

//pos connect bluetooth callback
-(void) onRequestQposConnected{
    NSLog(@"onRequestQposConnected");
    if ([self.bluetoothAddress  isEqual: @"audioType"]) {
        self.textViewLog.text = NSLocalizedString( @"AudioType connected.", nil);
    }else{
        self.textViewLog.text = NSLocalizedString(@"Bluetooth connected.", nil);
    }
}

//disconnect bluetooth
- (IBAction)disconnect:(id)sender {
    [pos disconnectBT];
}

//connect lbluttooh fail
-(void) onRequestQposDisconnected{
    NSLog(@"onRequestQposDisconnected");
    self.textViewLog.text = NSLocalizedString(@"pos disconnected.", nil);
}

//No Qpos Detected
-(void) onRequestNoQposDetected{
    NSLog(@"onRequestNoQposDetected");
    self.textViewLog.text = NSLocalizedString(@"No pos detected.", nil);
}

//start do trade button
- (IBAction)doTrade:(id)sender {
    NSLog(@"doTrade");
    self.textViewLog.text = NSLocalizedString(@"Starting...", nil);
    _currencyCode = @"0156";
    [pos setCardTradeMode:CardTradeMode_SWIPE_TAP_INSERT_CARD];
    [pos doCheckCard:30];
}

//input transaction amount
-(void) onRequestSetAmount{
    NSLog(@"onRequestSetAmount");
    msgStr = @"Please set amount";
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Please set amount", nil) message:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [pos cancelSetAmount];
        NSLog(@"cancel Set Amount");
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Confirm", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        //获取第1个输入框；
        UITextField *titleTextField = alertController.textFields.firstObject;
        NSString *inputAmount = titleTextField.text;
        NSLog(@"inputAmount = %@",inputAmount);
        self.lableAmount.text = [NSString stringWithFormat:@"$%@", [self checkAmount:inputAmount]];
        [pos setAmount:inputAmount aAmountDescribe:@"123" currency:_currencyCode transactionType:mTransType];
        self.amount = [NSString stringWithFormat:@"%@", [self checkAmount:inputAmount]];
        self.cashbackAmount = @"123";
    }]];
    [alertController addTextFieldWithConfigurationHandler:nil];
    [self presentViewController:alertController animated:YES completion:nil];
}

//callback of input pin on phone
-(void) onRequestPinEntry{
    NSLog(@"onRequestPinEntry");
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Please set pin", nil) message:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [pos cancelPinEntry];
        NSLog(@"cancel pin entry");
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Confirm", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        //获取第1个输入框；
        UITextField *titleTextField = alertController.textFields.firstObject;
        NSString *pinStr = titleTextField.text;
        NSLog(@"pinStr = %@",pinStr);
        [pos sendPinEntryResult:pinStr];
    }]];
    [alertController addTextFieldWithConfigurationHandler:nil];
    [self presentViewController:alertController animated:YES completion:nil];
}

// Prompt user to insert/swipe/tap card
-(void) onRequestWaitingUser{
    NSLog(@"onRequestWaitingUser");
    self.textViewLog.text = NSLocalizedString(@"Please insert/swipe/tap card now.", nil);
}

//return NFC and swipe card data on this function.
-(void) onDoTradeResult: (DoTradeResult)result DecodeData:(NSDictionary*)decodeData{
    if (result == DoTradeResult_NONE) {
        self.textViewLog.text = @"No card detected. Please insert or swipe card again and press check card.";
        NSLog(@"onDoTradeResult: %@", self.textViewLog.text);
        [pos doTrade:30];
    }else if (result==DoTradeResult_ICC) {
        self.textViewLog.text = @"ICC Card Inserted";
        NSLog(@"onDoTradeResult: %@", self.textViewLog.text);
        //Use this API to activate chip card transactions
        [pos doEmvApp:EmvOption_START];
    }else if(result==DoTradeResult_NOT_ICC){
        self.textViewLog.text = @"Card Inserted (Not ICC)";
        NSLog(@"onDoTradeResult: %@", self.textViewLog.text);
    }else if(result==DoTradeResult_MCR){
        NSString *formatID = [NSString stringWithFormat:@"Format ID: %@\n",decodeData[@"formatID"]] ;
        NSString *maskedPAN = [NSString stringWithFormat:@"Masked PAN: %@\n",decodeData[@"maskedPAN"]];
        NSString *expiryDate = [NSString stringWithFormat:@"Expiry Date: %@\n",decodeData[@"expiryDate"]];
        NSString *cardHolderName = [NSString stringWithFormat:@"Cardholder Name: %@\n",decodeData[@"cardholderName"]];
        NSString *serviceCode = [NSString stringWithFormat:@"Service Code: %@\n",decodeData[@"serviceCode"]];
        NSString *encTrack1 = [NSString stringWithFormat:@"Encrypted Track 1: %@\n",decodeData[@"encTrack1"]];
        NSString *encTrack2 = [NSString stringWithFormat:@"Encrypted Track 2: %@\n",decodeData[@"encTrack2"]];
        NSString *encTrack3 = [NSString stringWithFormat:@"Encrypted Track 3: %@\n",decodeData[@"encTrack3"]];
        NSString *pinKsn = [NSString stringWithFormat:@"PIN KSN: %@\n",decodeData[@"pinKsn"]];
        NSString *trackksn = [NSString stringWithFormat:@"Track KSN: %@\n",decodeData[@"trackksn"]];
        NSString *pinBlock = [NSString stringWithFormat:@"pinBlock: %@\n",decodeData[@"pinblock"]];
        NSString *encPAN = [NSString stringWithFormat:@"encPAN: %@\n",decodeData[@"encPAN"]];
        NSString *msg = [NSString stringWithFormat:NSLocalizedString(@"Card Swiped:\n", nil)];
        msg = [msg stringByAppendingString:formatID];
        msg = [msg stringByAppendingString:maskedPAN];
        msg = [msg stringByAppendingString:expiryDate];
        msg = [msg stringByAppendingString:cardHolderName];
        msg = [msg stringByAppendingString:pinKsn];
        msg = [msg stringByAppendingString:trackksn];
        msg = [msg stringByAppendingString:serviceCode];
        msg = [msg stringByAppendingString:encTrack1];
        msg = [msg stringByAppendingString:encTrack2];
        msg = [msg stringByAppendingString:encTrack3];
        msg = [msg stringByAppendingString:pinBlock];
        msg = [msg stringByAppendingString:encPAN];
        NSString *a = [QPOSUtil byteArray2Hex:[QPOSUtil stringFormatTAscii:maskedPAN]];
        [pos getPin:1 keyIndex:0 maxLen:6 typeFace:@"Pls Input Pin" cardNo:a data:@"" delay:30 withResultBlock:^(BOOL isSuccess, NSDictionary *result) {
            NSLog(@"result: %@",result);
            self.textViewLog.backgroundColor = [UIColor greenColor];
            [self playAudio];
            AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);
            self.textViewLog.text = msg;
            self.lableAmount.text = @"";
        }];
        NSLog(@"onDoTradeResult: %@", self.textViewLog.text);
    }else if(result==DoTradeResult_NFC_OFFLINE || result == DoTradeResult_NFC_ONLINE){
        NSString *formatID = [NSString stringWithFormat:@"Format ID: %@\n",decodeData[@"formatID"]] ;
        NSString *maskedPAN = [NSString stringWithFormat:@"Masked PAN: %@\n",decodeData[@"maskedPAN"]];
        NSString *expiryDate = [NSString stringWithFormat:@"Expiry Date: %@\n",decodeData[@"expiryDate"]];
        NSString *cardHolderName = [NSString stringWithFormat:@"Cardholder Name: %@\n",decodeData[@"cardholderName"]];
        NSString *serviceCode = [NSString stringWithFormat:@"Service Code: %@\n",decodeData[@"serviceCode"]];
        NSString *encTrack1 = [NSString stringWithFormat:@"Encrypted Track 1: %@\n",decodeData[@"encTrack1"]];
        NSString *encTrack2 = [NSString stringWithFormat:@"Encrypted Track 2: %@\n",decodeData[@"encTrack2"]];
        NSString *encTrack3 = [NSString stringWithFormat:@"Encrypted Track 3: %@\n",decodeData[@"encTrack3"]];
        NSString *pinKsn = [NSString stringWithFormat:@"PIN KSN: %@\n",decodeData[@"pinKsn"]];
        NSString *trackksn = [NSString stringWithFormat:@"Track KSN: %@\n",decodeData[@"trackksn"]];
        NSString *pinBlock = [NSString stringWithFormat:@"pinBlock: %@\n",decodeData[@"pinBlock"]];
        NSString *encPAN = [NSString stringWithFormat:@"encPAN: %@\n",decodeData[@"encPAN"]];
        NSString *msg = [NSString stringWithFormat:NSLocalizedString(@"Tap Card:\n", nil)];
        msg = [msg stringByAppendingString:formatID];
        msg = [msg stringByAppendingString:maskedPAN];
        msg = [msg stringByAppendingString:expiryDate];
        msg = [msg stringByAppendingString:cardHolderName];
        msg = [msg stringByAppendingString:pinKsn];
        msg = [msg stringByAppendingString:trackksn];
        msg = [msg stringByAppendingString:serviceCode];
        msg = [msg stringByAppendingString:encTrack1];
        msg = [msg stringByAppendingString:encTrack2];
        msg = [msg stringByAppendingString:encTrack3];
        msg = [msg stringByAppendingString:pinBlock];
        msg = [msg stringByAppendingString:encPAN];
        
        [pos getNFCBatchData:^(NSDictionary *dict) {
            NSString *tlv;
            if(dict !=nil){
                tlv= [NSString stringWithFormat:@"NFCBatchData: %@\n",dict[@"tlv"]];
            }else{
                tlv = @"";
            }
            self.textViewLog.backgroundColor = [UIColor greenColor];
            [self playAudio];
            AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);
            self.textViewLog.text = [msg stringByAppendingString:tlv];
            self.lableAmount.text = @"";
            NSLog(@"onDoTradeResult: %@", self.textViewLog.text);
        }];
    }else if(result==DoTradeResult_NFC_DECLINED){
        self.textViewLog.text = @"Tap Card Declined";
        NSLog(@"onDoTradeResult: %@", self.textViewLog.text);
    }else if (result==DoTradeResult_NO_RESPONSE){
        self.textViewLog.text = @"Check card no response";
        NSLog(@"onDoTradeResult: %@", self.textViewLog.text);
    }else if(result==DoTradeResult_BAD_SWIPE){
        self.textViewLog.text = @"Bad Swipe. \nPlease swipe again and press check card.";
        NSLog(@"onDoTradeResult: %@", self.textViewLog.text);
    }else if(result==DoTradeResult_NO_UPDATE_WORK_KEY){
        self.textViewLog.text = @"device not update work key";
        NSLog(@"onDoTradeResult: %@", self.textViewLog.text);
    }else if(result==DoTradeResult_CARD_NOT_SUPPORT){
        self.textViewLog.text = @"card not support";
        NSLog(@"onDoTradeResult: %@", self.textViewLog.text);
    }else if(result==DoTradeResult_PLS_SEE_PHONE){
        self.textViewLog.text = @"pls see phone";
        NSLog(@"onDoTradeResult: %@", self.textViewLog.text);
    }else if(result==DoTradeResult_TRY_ANOTHER_INTERFACE){
        self.textViewLog.text = @"pls try another interface";
        NSLog(@"onDoTradeResult: %@", self.textViewLog.text);
    }
}

- (void)playAudio{
    if(![self.bluetoothAddress isEqualToString:@"audioType"]){
        SystemSoundID soundID;
        NSString *strSoundFile = [[NSBundle mainBundle] pathForResource:@"1801" ofType:@"wav"];
        AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:strSoundFile],&soundID);
        AudioServicesPlaySystemSound(soundID);
    }
}

//send current transaction time to pos
-(void) onRequestTime{
    NSLog(@"onRequestTime");
    NSString *formatStringForHours = [NSDateFormatter dateFormatFromTemplate:@"j" options:0 locale:[NSLocale currentLocale]];
    NSRange containA = [formatStringForHours rangeOfString:@"a"];
    BOOL hasAMPM = containA.location != NSNotFound;
    //when phone time is 12h format, need add this judgement.
    if (hasAMPM) {
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        [dateFormatter setDateFormat:@"yyyyMMddhhmmss"];
        _terminalTime = [dateFormatter stringFromDate:[NSDate date]];
    }else{
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
        _terminalTime = [dateFormatter stringFromDate:[NSDate date]];
    }
    [pos sendTime:_terminalTime];
}

//Prompt message
-(void) onRequestDisplay: (Display)displayMsg{
    NSString *msg = @"";
    if (displayMsg==Display_CLEAR_DISPLAY_MSG) {
        msg = @"";
    }else if(displayMsg==Display_PLEASE_WAIT){
        msg = NSLocalizedString(@"Please wait...", nil);
    }else if(displayMsg==Display_REMOVE_CARD){
        msg = NSLocalizedString(@"Please remove card", nil);
    }else if (displayMsg==Display_TRY_ANOTHER_INTERFACE){
        msg = NSLocalizedString(@"Please try another interface", nil);
    }else if (displayMsg == Display_TRANSACTION_TERMINATED){
        msg = NSLocalizedString(@"Terminated", nil);
    }else if (displayMsg == Display_PIN_OK){
        msg = @"Pin ok";
    }else if (displayMsg == Display_INPUT_PIN_ING){
        msg = NSLocalizedString(@"please input pin on pos", nil);
    }else if (displayMsg == Display_MAG_TO_ICC_TRADE){
        msg = NSLocalizedString(@"please insert chip card on pos", nil);
    }else if (displayMsg == Display_INPUT_OFFLINE_PIN_ONLY){
        msg = NSLocalizedString(@"please input offline pin only", nil);
    }else if(displayMsg == Display_CARD_REMOVED){
        msg = NSLocalizedString(@"Card Removed", nil);
    }else if (displayMsg == Display_INPUT_LAST_OFFLINE_PIN){
        msg = NSLocalizedString(@"please input last offline pin", nil);
    }else if (displayMsg == Display_PROCESSING){
        msg = NSLocalizedString(@"processing...", nil);
    }
    self.textViewLog.text = msg;
    NSLog(@"onRequestDisplay: %@", msg);
}

//Multiple AIDS select
-(void) onRequestSelectEmvApp: (NSArray*)appList{
    NSLog(@"onRequestSelectEmvApp: %@", appList);
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Please select app", nil) message:@"" preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        NSLog(@"cancel select app");
        [pos cancelSelectEmvApp];
    }]];
    for (int i=0 ; i<[appList count] ; i++){
        NSLog(@"i = %d", i);
        NSString *emvApp = [appList objectAtIndex:i];
        [alertController addAction:[UIAlertAction actionWithTitle:emvApp style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSLog(@"action: %@ i = %d", action.title, i);
            [pos selectEmvApp:i];
        }]];
    }
    [self presentViewController:alertController animated:YES completion:nil];
}

//return chip card tlv data on this function
-(void) onRequestOnlineProcess: (NSString*) tlv{
    NSLog(@"onRequestOnlineProcess = %@",[[QPOSService sharedInstance] anlysEmvIccData:tlv]);
/*
    NSArray *dict = [TLVParser parse:tlv];
    for (TLV *tlv in dict) {
        NSLog(@"tag: %@ length: %@ value: %@",tlv.tag,tlv.length,tlv.value);
    }
    [pos getEncryptedTrack2Data:^(NSString *ksn, NSString *track2Data) {
        NSLog(@"ksn: %@ track2Data: %@",ksn,track2Data);
    }];
*/
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Request data to server.", nil) message:@"" preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Confirm", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        //send transaction to bank and request bank approval
        [pos sendOnlineProcessResult:@"8A023030"];
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

// transaction result callback function
-(void) onRequestTransactionResult: (TransactionResult)transactionResult{
    NSString *messageTextView = @"";
    if (transactionResult==TransactionResult_APPROVED) {
        NSString *message = [NSString stringWithFormat:@"Approved\nAmount: $%@\n",amount];
        if([cashbackAmount isEqualToString:@""]) {
            message = [message stringByAppendingString:@"Cashback: $"];
            message = [message stringByAppendingString:cashbackAmount];
        }
        messageTextView = message;
        self.textViewLog.backgroundColor = [UIColor greenColor];
        [self playAudio];
    }else if(transactionResult == TransactionResult_TERMINATED) {
        [self clearDisplay];
        messageTextView = @"Terminated";
    } else if(transactionResult == TransactionResult_DECLINED) {
        messageTextView = @"Declined";
    } else if(transactionResult == TransactionResult_CANCEL) {
        [self clearDisplay];
        messageTextView = @"Cancel";
    } else if(transactionResult == TransactionResult_CAPK_FAIL) {
        [self clearDisplay];
        messageTextView = @"Fail (CAPK fail)";
    } else if(transactionResult == TransactionResult_NOT_ICC) {
        [self clearDisplay];
        messageTextView = @"Fail (Not ICC card)";
    } else if(transactionResult == TransactionResult_SELECT_APP_FAIL) {
        [self clearDisplay];
        messageTextView = @"Fail (App fail)";
    } else if(transactionResult == TransactionResult_DEVICE_ERROR) {
        [self clearDisplay];
        messageTextView = @"Pos Error";
    } else if(transactionResult == TransactionResult_CARD_NOT_SUPPORTED) {
        [self clearDisplay];
        messageTextView = @"Card not support";
    } else if(transactionResult == TransactionResult_MISSING_MANDATORY_DATA) {
        [self clearDisplay];
        messageTextView = @"Missing mandatory data";
    } else if(transactionResult == TransactionResult_CARD_BLOCKED_OR_NO_EMV_APPS) {
        [self clearDisplay];
        messageTextView = @"Card blocked or no EMV apps";
    } else if(transactionResult == TransactionResult_INVALID_ICC_DATA) {
        [self clearDisplay];
        messageTextView = @"Invalid ICC data";
    }else if(transactionResult == TransactionResult_NFC_TERMINATED) {
        [self clearDisplay];
        messageTextView = @"NFC Terminated";
    }else if(transactionResult == TransactionResult_CONTACTLESS_TRANSACTION_NOT_ALLOW) {
        [self clearDisplay];
        messageTextView = @"TRANS NOT ALLOW";
    }else if(transactionResult == TransactionResult_CARD_BLOCKED) {
        [self clearDisplay];
        messageTextView = @"Card Blocked";
    }else if(transactionResult == TransactionResult_TOKEN_INVALID) {
        [self clearDisplay];
        messageTextView = @"Token Invalid";
    }else if(transactionResult == TransactionResult_APP_BLOCKED) {
        [self clearDisplay];
        messageTextView = @"APP Blocked";
    }else if(transactionResult == TransactionResult_MULTIPLE_CARDS) {
        [self clearDisplay];
        messageTextView = @"Multiple Cards";
    }
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Transaction Result", nil) message:messageTextView preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Confirm", nil) style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
    self.amount = @"";
    self.cashbackAmount = @"";
    self.lableAmount.text = @"";
    msgStr = @"Transaction Result";
    NSLog(@"onRequestTransactionResult: %@",messageTextView);
}

-(void) onRequestTransactionLog: (NSString*)tlv{
    NSLog(@"onTransactionLog %@",tlv);
}

//return transaction batch data
-(void) onRequestBatchData: (NSString*)tlv{
    NSLog(@"onBatchData %@",tlv);
    tlv = [@"batch data:\n" stringByAppendingString:tlv];
    self.textViewLog.text = tlv;
}

//return transaction reversal data
-(void) onReturnReversalData: (NSString*)tlv{
    NSLog(@"onReversalData %@",tlv);
    tlv = [@"reversal data:\n" stringByAppendingString:tlv];
    self.textViewLog.text = tlv;
}

-(void) onEmvICCExceptionData: (NSString*)tlv{
    NSLog(@"onEmvICCExceptionData:%@",tlv);
}

//cancel transaction api.
- (IBAction)resetpos:(id)sender {
    NSLog(@"resetpos");
    self.textViewLog.backgroundColor = [UIColor greenColor];
    self.textViewLog.text = @"reset pos ... ";
    if([pos resetPosStatus]){
        self.textViewLog.text = @"reset pos success";
    }else{
        self.textViewLog.text = @"reset pos fail";
    }
}

//Prompt error message in this function
-(void) onDHError: (DHError)errorState{
    NSString *msg = @"";
    if(errorState ==DHError_TIMEOUT) {
        msg = @"Pos no response";
    } else if(errorState == DHError_DEVICE_RESET) {
        msg = @"Pos reset";
    } else if(errorState == DHError_UNKNOWN) {
        msg = @"Unknown error";
    } else if(errorState == DHError_DEVICE_BUSY) {
        msg = @"Pos Busy";
    } else if(errorState == DHError_INPUT_OUT_OF_RANGE) {
        msg = @"Input out of range.";
        [pos resetPosStatus];
    } else if(errorState == DHError_INPUT_INVALID_FORMAT) {
        msg = @"Input invalid format.";
    } else if(errorState == DHError_INPUT_ZERO_VALUES) {
        msg = @"Input are zero values.";
    } else if(errorState == DHError_INPUT_INVALID) {
        msg = @"Input invalid.";
    } else if(errorState == DHError_CASHBACK_NOT_SUPPORTED) {
        msg = @"Cashback not supported.";
    } else if(errorState == DHError_CRC_ERROR) {
        msg = @"CRC Error.";
    } else if(errorState == DHError_COMM_ERROR) {
        msg = @"Communication Error.";
    }else if(errorState == DHError_MAC_ERROR){
        msg = @"MAC Error.";
    }else if(errorState == DHError_CMD_TIMEOUT){
        msg = @"CMD Timeout.";
    }else if(errorState == DHError_AMOUNT_OUT_OF_LIMIT){
        msg = @"Amount out of limit.";
    }
    self.textViewLog.text = msg;
    NSLog(@"onError = %@",msg);
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:msg message:@"" preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alertController animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alertController dismissViewControllerAnimated:YES completion:nil];
    });
}

//get pos id in this function.
- (IBAction)getQposId:(id)sender {
    NSLog(@"getQposId");
    [pos getQPosId];
}

// callback function of getQposId api
-(void) onQposIdResult: (NSDictionary*)posId{
    NSString *aStr = [@"posId:" stringByAppendingString:posId[@"posId"]];
    
    NSString *temp = [@"psamId:" stringByAppendingString:posId[@"psamId"]];
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:temp];
    
    temp = [@"merchantId:" stringByAppendingString:posId[@"merchantId"]];
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:temp];
    
    temp = [@"vendorCode:" stringByAppendingString:posId[@"vendorCode"]];
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:temp];
    
    temp = [@"deviceNumber:" stringByAppendingString:posId[@"deviceNumber"]];
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:temp];
    
    temp = [@"psamNo:" stringByAppendingString:posId[@"psamNo"]];
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:temp];
    
    temp = [@"isSupportNFC:" stringByAppendingString:posId[@"isSupportNFC"]];
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:temp];
    
    self.textViewLog.text = aStr;
    NSLog(@"onQposIdResult: %@",aStr);
}

//get pos info function
- (IBAction)getPosInfo:(id)sender {
    NSLog(@"getPosInfo");
   [pos getQPosInfo];
}

//callback function of getPosInfo api.
-(void) onQposInfoResult: (NSDictionary*)posInfoData{
    NSString *aStr = @"Bootloader Version: ";
    aStr = [aStr stringByAppendingString:posInfoData[@"bootloaderVersion"]];
    
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:@"Firmware Version: "];
    aStr = [aStr stringByAppendingString:posInfoData[@"firmwareVersion"]];
    
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:@"Hardware Version: "];
    aStr = [aStr stringByAppendingString:posInfoData[@"hardwareVersion"]];
    
    NSString *batteryPercentage = posInfoData[@"batteryPercentage"];
    if (batteryPercentage==nil || [@"" isEqualToString:batteryPercentage]) {
        aStr = [aStr stringByAppendingString:@"\n"];
        aStr = [aStr stringByAppendingString:@"Battery Level: "];
        aStr = [aStr stringByAppendingString:posInfoData[@"batteryLevel"]];
        
    }else{
        aStr = [aStr stringByAppendingString:@"\n"];
        aStr = [aStr stringByAppendingString:@"Battery Percentage: "];
        aStr = [aStr stringByAppendingString:posInfoData[@"batteryPercentage"]];
    }
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:@"Charge: "];
    aStr = [aStr stringByAppendingString:posInfoData[@"isCharging"]];
    
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:@"USB: "];
    aStr = [aStr stringByAppendingString:posInfoData[@"isUsbConnected"]];
    
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:@"Track 1 Supported: "];
    aStr = [aStr stringByAppendingString:posInfoData[@"isSupportedTrack1"]];
    
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:@"Track 2 Supported: "];
    aStr = [aStr stringByAppendingString:posInfoData[@"isSupportedTrack2"]];
    
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:@"Track 3 Supported: "];
    aStr = [aStr stringByAppendingString:posInfoData[@"isSupportedTrack3"]];
    
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:@"updateWorkKeyFlag: "];
    aStr = [aStr stringByAppendingString:posInfoData[@"updateWorkKeyFlag"]];
    
    self.textViewLog.text = aStr;
    NSLog(@"onQposInfoResult: %@",aStr);
}

//eg: update TMK api in pos.
-(void)setMasterKey:(NSInteger)keyIndex{
    NSLog(@"setMasterKey");
    NSString *pik = @"89EEF94D28AA2DC189EEF94D28AA2DC1";//111111111111111111111111
    NSString *pikCheck = @"82E13665B4624DF5";
    pik = @"F679786E2411E3DEF679786E2411E3DE";//33333333333333333333333333333
    pikCheck = @"ADC67D8473BF2F06";
    [pos setMasterKey:pik checkValue:pikCheck keyIndex:keyIndex];
}

// callback function of setMasterKey api
-(void) onReturnSetMasterKeyResult: (BOOL)isSuccess{
    if(isSuccess){
        self.textViewLog.text = @"Success";
    }else{
        self.textViewLog.text =  @"Failed";
    }
    NSLog(@"onReturnSetMasterKeyResult: %@",self.textViewLog.text);
}

//eg: update work key in pos.
-(void)updateWorkKey:(NSInteger)keyIndex{
    NSLog(@"updateWorkKey");
    NSString * pik = @"89EEF94D28AA2DC189EEF94D28AA2DC1";
    NSString * pikCheck = @"82E13665B4624DF5";
    
    pik = @"89EEF94D28AA2DC189EEF94D28AA2DC1";
    pikCheck = @"82E13665B4624DF5";
    
    NSString * trk = @"89EEF94D28AA2DC189EEF94D28AA2DC1";
    NSString * trkCheck = @"82E13665B4624DF5";
    
    NSString * mak = @"89EEF94D28AA2DC189EEF94D28AA2DC1";
    NSString * makCheck = @"82E13665B4624DF5";
    [pos udpateWorkKey:pik pinKeyCheck:pikCheck trackKey:trk trackKeyCheck:trkCheck macKey:mak macKeyCheck:makCheck keyIndex:keyIndex];
}

// callback function of updateWorkKey api.
-(void) onRequestUpdateWorkKeyResult:(UpdateInformationResult)updateInformationResult{
    if (updateInformationResult==UpdateInformationResult_UPDATE_SUCCESS) {
        self.textViewLog.text = @" update workkey Success";
    }else if(updateInformationResult==UpdateInformationResult_UPDATE_FAIL){
        self.textViewLog.text =  @"Failed";
    }else if(updateInformationResult==UpdateInformationResult_UPDATE_PACKET_LEN_ERROR){
        self.textViewLog.text =  @"Packet len error";
    }else if(updateInformationResult==UpdateInformationResult_UPDATE_PACKET_VEFIRY_ERROR){
        [pos getUpdateCheckValueBlock:^(BOOL isSuccess, NSString *stateStr) {
            self.textViewLog.text = [@"Packet vefiry error " stringByAppendingString:stateStr];
        }];
    }
    NSLog(@"onRequestUpdateWorkKeyResult %@",self.textViewLog.text);
}

//update ipek
- (void)updateIpek{
    NSLog(@"updateIpek");
     [pos doUpdateIPEKOperation:@"00" tracksn:@"00000510F462F8400004" trackipek:@"293C2D8B1D7ABCF83E665A7C5C6532C9" trackipekCheckValue:@"93906AA157EE2604" emvksn:@"00000510F462F8400004" emvipek:@"293C2D8B1D7ABCF83E665A7C5C6532C9" emvipekcheckvalue:@"93906AA157EE2604" pinksn:@"00000510F462F8400004" pinipek:@"293C2D8B1D7ABCF83E665A7C5C6532C9" pinipekcheckValue:@"93906AA157EE2604" block:^(BOOL isSuccess, NSString *stateStr) {
        if (isSuccess) {
            self.textViewLog.text = stateStr;
        }
    }];
}

//update ipek by key type
- (void)updateIpekByKeyType{
    NSLog(@"updateIpekByKeyType");
     [pos updateIPEKOperationByKeyType:@"00" tracksn:@"00000510F462F8400004" trackipek:@"98357D2CA022B6E298357D2CA022B6E2" trackipekCheckValue:@"82E13665B4624DF5" emvksn:@"00000510F462F8400004" emvipek:@"98357D2CA022B6E298357D2CA022B6E2" emvipekcheckvalue:@"82E13665B4624DF5" pinksn:@"" pinipek:@"" pinipekcheckValue:@"" block:^(BOOL isSuccess, NSString *stateStr) {
        if (isSuccess) {
            self.textViewLog.text = stateStr;
        }
    }];
}
- (IBAction)updateEMVConfig:(id)sender {
    [self updateEMVConfigByXML];
}

//eg: use emv_app.bin and emv_capk.bin file to update emv configure in pos,Update time is about two minutes
//-(void)UpdateEmvCfg{
//    NSLog(@"UpdateEmvCfg");
//    NSString *emvAppCfg = [QPOSUtil byteArray2Hex:[self readLine:@"emv_app"]];
//    NSString *emvCapkCfg = [QPOSUtil byteArray2Hex:[self readLine:@"emv_capk"]];
//    [pos updateEmvConfig:emvAppCfg emvCapk:emvCapkCfg];
//}

//eg: read xml file to update emv configure
- (void)updateEMVConfigByXML{
    self.textViewLog.text =  @"start update emv configure,pls wait";
    NSLog(@"updateEMVConfigByXML,pls wait");
    NSData *xmlData = [self readLine:@"QPOS cute,CR100,D20,D30"];
    NSString *xmlStr = [QPOSUtil asciiFormatString:xmlData];
    [pos updateEMVConfigByXml:xmlStr];
}

// callback function of updateEmvConfig and updateEMVConfigByXml api.
-(void)onReturnCustomConfigResult:(BOOL)isSuccess config:(NSString*)resutl{
    if(isSuccess){
        self.textViewLog.text = @"Success";
        self.textViewLog.backgroundColor = [UIColor greenColor];
    }else{
        self.textViewLog.text =  @"Failed";
    }
    NSLog(@"onReturnCustomConfigResult: %@",self.textViewLog.text);
}

//update emv configure by TLV data
-(void)updateEMVConfigByTlv{
    NSString *appTlvData = @"9F0607A00000000310109F3303E0F8C8";
    [pos updateEmvAPPByTlv:EMVOperation_update appTlv:appTlvData];
    
    NSString *capkTlvData = @"9F0605A0000000039F220107";
    [pos updateEmvCAPKByTlv:EMVOperation_update capkTlv:capkTlvData];
}
//callback of update emv configure api by TLV data
- (void)onReturnUpdateEMVResult:(BOOL)isSuccess{
    NSLog(@"onReturnUpdateEMVResult:%d",isSuccess);
    if (isSuccess) {
        self.textViewLog.text = @"Success";
    }else{
        self.textViewLog.text = @"fail";
    }
}
//callback of update emv configure api by TLV data
- (void)onReturnGetEMVListResult:(NSString *)result{
    NSLog(@"%@",result);
    self.textViewLog.text = result;
}
//callback of update emv configure api by TLV data
- (void)onReturnUpdateEMVRIDResult:(BOOL)isSuccess{
    NSLog(@"onReturnUpdateEMVRIDResult:%d",isSuccess);
    if (isSuccess) {
        self.textViewLog.text = @"Success";
    }else{
        self.textViewLog.text = @"fail";
    }
}

// update pos firmware api
- (void)updatePosFirmware:(UIButton *)sender {
    NSData *data = [self readLine:@"A27CAYC_S1_master"];//read a14upgrader.asc
    if (data != nil) {
        [pos updatePosFirmware:data address:self.bluetoothAddress];
        self.updateFWFlag = true;
        dispatch_async(dispatch_queue_create(0, 0), ^{
            while (true) {
                [NSThread sleepForTimeInterval:0.1];
                NSInteger progress = [pos getUpdateProgress];
                if (progress < 100) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (!self.updateFWFlag) {
                            return;
                        }
                        self.textViewLog.text = [NSString stringWithFormat:@"Current progress:%ld%%",(long)progress];
                    });
                    continue;
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.textViewLog.text = @"finish upgrader";
                });
                break;
            }
        });
    }else{
        self.textViewLog.text = @"pls make sure you have passed the right data";
    }
}

// callback function of updatePosFirmware api.
-(void) onUpdatePosFirmwareResult:(UpdateInformationResult)updateInformationResult{
    NSLog(@"%ld",(long)updateInformationResult);
    self.updateFWFlag = false;
    if (updateInformationResult==UpdateInformationResult_UPDATE_SUCCESS) {
        self.textViewLog.text = @"Success";
    }else if(updateInformationResult==UpdateInformationResult_UPDATE_FAIL){
        self.textViewLog.text =  @"Failed";
    }else if(updateInformationResult==UpdateInformationResult_UPDATE_PACKET_LEN_ERROR){
        self.textViewLog.text =  @"Packet len error";
    }else if(updateInformationResult==UpdateInformationResult_UPDATE_PACKET_VEFIRY_ERROR){
        self.textViewLog.text =  @"Packer vefiry error";
    }else if(updateInformationResult==UpdateInformationResult_UPDATE_PLEASE_PLUG_INTO_POWER){
        self.textViewLog.text =  @"Please plug into power";
    }else{
        self.textViewLog.text = @"firmware updating...";
    }
}

//get encrypt data function
- (void)getEncryptData{
    NSData *data = [@"123456789" dataUsingEncoding:NSUTF8StringEncoding];;
    [pos getEncryptData:data keyType:@"2" keyIndex:@"0" timeOut:10];
}

- (void)onReturnGetEncryptDataResult:(NSDictionary *)tlv{
    NSLog(@"onReturnGetEncryptDataResult: %@", tlv);
}

//update public key into pos
- (void)updateRSATest{
    NSString *pemStr = [QPOSUtil asciiFormatString: [self readLine:@"rsa_public_key_pkcs8_test"]];
    NSLog(@"pemStr: %@", pemStr);
    [pos updateRSA:pemStr pemFile:@"rsa_public_key_pkcs8_test.pem"];
}

// callback function of updateRSA function
-(void)onDoSetRsaPublicKey:(BOOL)result{
    NSLog(@"onDoSetRsaPublicKey: %d", result);
    if (result) {
        self.textViewLog.text = @"success";
    }else{
        self.textViewLog.text = @"fail";
    }
}

//generate Session Keys from pos
- (void)generateSessionKeysTest{
    [pos generateSessionKeys];
}

-(void)onQposGenerateSessionKeysResult:(NSDictionary *)result{
    NSLog(@"onQposGenerateSessionKeysResult: %@", result);
}

-(void) onGetPosComm:(NSInteger)mode amount:(NSString *)amt posId:(NSString*)aPosId{
    if(mode == 1){
        [pos doTrade:30];
    }
}

-(void)conductEventByMsg:(NSString *)msg{
    if ([msg isEqualToString:@"Online process requested."]){
        [pos isServerConnected:YES];
    }else if ([msg isEqualToString:@"Request data to server."]){
        [pos sendOnlineProcessResult:@"8A023030"];
    }else if ([msg isEqualToString:@"Transaction Result"]){
        
    }
}

//parse the xml file, update emv app
//- (void)updateEMVCfgByXML{
//    NSMutableArray *listArr = [NSMutableArray array];
//    NSArray *emvListArr = [self requestXMLData:EMVAppXMl];
//    TagApp *tag = emvListArr[4];
//    NSDictionary *emvDict = [pos EmvAppTag];
//    for (int i = 0 ; i < emvDict.allKeys.count; i++) {
//        NSString *key = emvDict.allKeys[i];
//        NSString * value = [tag valueForKey:key];
//        if (value.length != 0) {
//            NSString *tempStr = [[emvDict valueForKey:key] stringByAppendingString:value];
//            [listArr addObject:tempStr];
//        }
//    }
//
//    NSLog(@"===%@===数量：%lu",listArr,(unsigned long)listArr.count);
//    [pos updateEmvAPP:EMVOperation_update data:listArr block:^(BOOL isSuccess, NSString *stateStr) {
//        if (isSuccess) {
//            self.textViewLog.text = [NSString stringWithFormat:@"success:%@",stateStr];
//        }else{
//            NSLog(@"fail:%@",stateStr);
//            self.textViewLog.text = [NSString stringWithFormat:@"fail:%@",stateStr];
//        }
//    }];
//}

//parse the xml file,update emv capk
//- (void)updateCAPKConfigByXML{
//    NSArray *capkArr = [self requestXMLData:EMVCapkXMl];
//    NSMutableArray *capkTempArr = [NSMutableArray array];
//    TagCapk *capk = capkArr[1];
//    if (capk.Rid.length != 0) {
//        NSString *capkStr1 = [NSString stringWithFormat:@"9F06%@",capk.Rid];
//        [capkTempArr addObject:capkStr1];
//    }
//    if (capk.Public_Key_Index.length != 0) {
//        NSString *capkStr2 = [NSString stringWithFormat:@"9F22%@",capk.Public_Key_Index];
//        [capkTempArr addObject:capkStr2];
//    }
//    if (capk.Public_Key_Module.length != 0) {
//        NSString *capkStr3 = [NSString stringWithFormat:@"DF02%@",capk.Public_Key_Module];
//        [capkTempArr addObject:capkStr3];
//    }
//    if (capk.Public_Key_CheckValue.length != 0) {
//        NSString *capkStr4 = [NSString stringWithFormat:@"DF03%@",capk.Public_Key_CheckValue];
//        [capkTempArr addObject:capkStr4];
//    }
//    if (capk.Pk_exponent.length != 0) {
//        NSString *capkStr5 = [NSString stringWithFormat:@"DF04%@",capk.Pk_exponent];
//        [capkTempArr addObject:capkStr5];
//    }
//    if (capk.Expired_date.length != 0) {
//        NSString *capkStr6 = [NSString stringWithFormat:@"c%@",capk.Expired_date];
//        [capkTempArr addObject:capkStr6];
//    }
//    if (capk.Hash_algorithm_identification.length != 0) {
//        NSString *capkStr7 = [NSString stringWithFormat:@"DF06%@",capk.Hash_algorithm_identification];
//        [capkTempArr addObject:capkStr7];
//    }
//    if (capk.Pk_algorithm_identification.length != 0) {
//        NSString *capkStr8 = [NSString stringWithFormat:@"DF07%@",capk.Pk_algorithm_identification];
//        [capkTempArr addObject:capkStr8];
//    }
//
//    [pos updateEmvCAPK:EMVOperation_update data:capkTempArr.copy block:^(BOOL isSuccess, NSString *stateStr) {
//        if (isSuccess) {
//            self.textViewLog.text = [NSString stringWithFormat:@"success:%@",stateStr];
//        }else{
//            NSLog(@"fail:%@",stateStr);
//            self.textViewLog.text = [NSString stringWithFormat:@"fail:%@",stateStr];
//        }
//    }];
//}

//Analysis xml
- (NSArray *)requestXMLData:(EMVXML)appOrCapk {
    NSString *xml_Path = [[NSBundle mainBundle] pathForResource:@"emv_profile_tlv_20180717" ofType:@"xml"];
    NSData *xml_data = [[NSData alloc] initWithContentsOfFile:xml_Path];;
    GDataXMLDocument *document = [[GDataXMLDocument alloc] initWithData:xml_data error:NULL];
    GDataXMLElement *rootElement = document.rootElement;
    NSMutableArray *modelArray = [NSMutableArray array];
    for (GDataXMLElement *videoElement in rootElement.children) {
        if (appOrCapk == EMVAppXMl) {
            if ([videoElement.name isEqualToString:@"app"]) {
               TagApp *video = [[TagApp alloc] init];
                for (GDataXMLNode *attribute in videoElement.attributes) {
                    [video setValue:attribute.stringValue forKey:attribute.name];
                }
                for (GDataXMLElement *subVideoElement in videoElement.children) {
                    [video setValue:subVideoElement.stringValue forKey:subVideoElement.name];
                }
                [modelArray addObject:video];
            }
        }else{
            if ([videoElement.name isEqualToString:@"capk"]) {
               TagCapk *video = [[TagCapk alloc] init];
                for (GDataXMLNode *attribute in videoElement.attributes) {
                    [video setValue:attribute.stringValue forKey:attribute.name];
                }
                for (GDataXMLElement *subVideoElement in videoElement.children) {
                    [video setValue:subVideoElement.stringValue forKey:subVideoElement.name];
                }
                [modelArray addObject:video];
            }
        }
    }
    return modelArray.copy;
}

-(void)clearDisplay{
    self.textViewLog.text = @"";
}

-(NSString *)checkAmount:(NSString *)tradeAmount{
    NSString *rs = @"";
    NSInteger a = 0;
    if (tradeAmount==nil || [tradeAmount isEqualToString:@""]) {
        NSLog(@"trade amount is nil or empty");
        return rs;
    }

    if ([tradeAmount hasPrefix:@"0"]) {
        NSLog(@"trade amount is invalid");
        return rs;
    }
    
    if (![QPOSUtil isPureInt:tradeAmount]) {
        NSLog(@"trade amount is invalid");
        return rs;
    }
    
    a = [tradeAmount length];
    if (a == 1) {
        rs = [@"0.0" stringByAppendingString:tradeAmount];
    }else if (a==2){
        rs = [@"0." stringByAppendingString:tradeAmount];
    }else if(a > 2){
        rs = [tradeAmount substringWithRange:NSMakeRange(0, a-2)];
        rs = [rs stringByAppendingString:@"."];
        rs = [rs stringByAppendingString: [tradeAmount substringWithRange:NSMakeRange(a-2,2)]];
    }
    return rs;
}

- (NSData*)readLine:(NSString*)name{
    NSString* binFile = [[NSBundle mainBundle]pathForResource:name ofType:@".bin"];
    NSString* ascFile = [[NSBundle mainBundle]pathForResource:name ofType:@".asc"];
    NSString* xmlFile = [[NSBundle mainBundle]pathForResource:name ofType:@".xml"];
    NSString* pemFile = [[NSBundle mainBundle]pathForResource:name ofType:@".pem"];
    if (binFile!= nil && ![binFile isEqualToString: @""]) {
        NSFileManager* Manager = [NSFileManager defaultManager];
        NSData* data1 = [[NSData alloc] init];
        data1 = [Manager contentsAtPath:binFile];
        return data1;
    }else if (ascFile!= nil && ![ascFile isEqualToString: @""]){
        NSFileManager* Manager = [NSFileManager defaultManager];
        NSData* data2 = [[NSData alloc] init];
        data2 = [Manager contentsAtPath:ascFile];
        return data2;
    }else if (xmlFile!= nil && ![xmlFile isEqualToString: @""]){
        NSFileManager* Manager = [NSFileManager defaultManager];
        NSData* data2 = [[NSData alloc] init];
        data2 = [Manager contentsAtPath:xmlFile];
        return data2;
    }else if (pemFile!= nil && ![pemFile isEqualToString: @""]){
        NSFileManager* Manager = [NSFileManager defaultManager];
        NSData* data2 = [[NSData alloc] init];
        data2 = [Manager contentsAtPath:pemFile];
        NSLog(@"pemFile: %@", pemFile);
        return data2;
    }
    return nil;
}

// use iso-4 format to encrypt pin
- (NSString *)encryptedPinBlock:(NSString *)pin pan:(NSString *)pan random:(NSString *)random aesKey:(NSString *)aesKey{
    NSString *pinStr=@"4";
    NSString *pinLen = [NSString stringWithFormat:@"%lu", (unsigned long)pin.length];
    pinStr = [[pinStr stringByAppendingString:pinLen] stringByAppendingString:pin];
    NSInteger pinStrLen = 16 - pinStr.length;
    for (int i = 0; i < pinStrLen; i++) {
        pinStr = [pinStr stringByAppendingString:@"A"];
    }
    NSString *newRandom = [random substringToIndex:16];
    pinStr = [pinStr stringByAppendingString:newRandom];
    NSString *panStr = @"";
    NSString *panLen = [NSString stringWithFormat:@"%lu", (unsigned long)pan.length - 12];
    panStr = [panStr stringByAppendingString:panLen];
    panStr = [panStr stringByAppendingString:pan];
    NSInteger panStrLen = 32-panStr.length;
    for (int i = 0; i < panStrLen; i++) {
       panStr = [panStr stringByAppendingString:@"0"];
    }
    NSString *blockA = [self encryptOperation:kCCEncrypt value:pinStr key:aesKey];
    NSString *blockB = [self pinxCreator:panStr withPinv:blockA];
    NSString *pinblock = [self encryptOperation:kCCEncrypt value:blockB key:aesKey];
    return pinblock;
}

- (NSString *)pinxCreator:(NSString *)pan withPinv:(NSString *)pinv{
    if (pan.length != pinv.length){
        return nil;
    }
    const char *panchar = [pan UTF8String];
    const char *pinvchar = [pinv UTF8String];
    NSString *temp = [[NSString alloc] init];
    for (int i = 0; i < pan.length; i++){
        int panValue = [self charToint:panchar[i]];
        int pinvValue = [self charToint:pinvchar[i]];
        temp = [temp stringByAppendingString:[NSString stringWithFormat:@"%X",panValue^pinvValue]];
    }
    return temp;
}
- (int)charToint:(char)tempChar{
    if (tempChar >= '0' && tempChar <='9'){
        return tempChar - '0';
    }
    else if (tempChar >= 'A' && tempChar <= 'F'){
        return tempChar - 'A' + 10;
    }
    return 0;
}

- (NSString *)encryptOperation:(CCOperation)operation value:(NSString *)data key:(NSString *)key{
    NSUInteger blockSize = kCCBlockSizeAES128;
    NSUInteger dataLength = data.length;
    size_t bufferSize = dataLength + blockSize;
    void * buffer = malloc(bufferSize);
    size_t numBytesDecrypted = 0;
    NSData *dataKey = [QPOSUtil HexStringToByteArray:key];
    NSData *dataIn = [QPOSUtil HexStringToByteArray:data];
    CCCryptorStatus cryptStatus = CCCrypt(operation,
                                          kCCAlgorithmAES128,
                                          0x0000 | kCCOptionECBMode,
                                          dataKey.bytes,
                                          dataKey.length,
                                          0,
                                          dataIn.bytes,
                                          dataIn.length,
                                          buffer,
                                          bufferSize,
                                          &numBytesDecrypted);
    if (cryptStatus == kCCSuccess) {
        NSData * result = [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
        if (result != nil) {
            return [QPOSUtil byteArray2Hex:result];
        }
    } else {
        if (buffer) {
            free(buffer);
            buffer = NULL;
        }
    }
    return nil;
}

- (void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

