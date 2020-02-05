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
#import "DecryptTLV.h"

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

@end

@implementation MainDetailViewController{
    QPOSService *pos;
    UIAlertView *mAlertView;
    UIActionSheet *mActionSheet;
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
    self.btnResetPos.layer.cornerRadius = 10;
    
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
        self.textViewLog.text = @"connecting bluetooth...";
        [pos connectBT:self.bluetoothAddress];
        [pos setBTAutoDetecting:true];
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
        self.textViewLog.text = @"AudioType connected.";
    }else{
        self.textViewLog.text = @"Bluetooth connected.";
    }
    
}
//disconnect bluetooth
- (IBAction)disconnect:(id)sender {
    NSLog(@"disconnect");
    [pos disconnectBT];
}

//connect lbluttooh fail
-(void) onRequestQposDisconnected{
    NSLog(@"onRequestQposDisconnected");
    self.textViewLog.text = @"pos disconnected.";
}

//No Qpos Detected
-(void) onRequestNoQposDetected{
    NSLog(@"onRequestNoQposDetected");
    self.textViewLog.text = @"No pos detected.";
}

//start do trade button
- (IBAction)doTrade:(id)sender {
    self.textViewLog.backgroundColor = [UIColor whiteColor];
    self.textViewLog.text = @"Starting...";
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    _terminalTime = [dateFormatter stringFromDate:[NSDate date]];
    _currencyCode = @"0156";
    [pos setCardTradeMode:CardTradeMode_SWIPE_TAP_INSERT_CARD_NOTUP];
    [pos doCheckCard];
}

//input transaction amount
-(void) onRequestSetAmount{
    NSString *msg = @"";
    mAlertView = [[UIAlertView new]
                  initWithTitle:@"Please set amount"
                  message:msg
                  delegate:self
                  cancelButtonTitle:@"Confirm"
                  otherButtonTitles:@"Cancel",
                  nil ];
    [mAlertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
    [mAlertView show];
    msgStr = @"Please set amount";
}

-(void) onRequestPinEntry{
    NSLog(@"onRequestPinEntry");
    NSString *msg = @"";
    mAlertView = [[UIAlertView new]
                  initWithTitle:@"input pin..."
                  message:msg
                  delegate:self
                  cancelButtonTitle:@"Confirm"
                  otherButtonTitles:@"Cancel",
                  nil ];
    [mAlertView setAlertViewStyle:UIAlertViewStyleSecureTextInput];
    //UIAlertViewStylePlainTextInput
    [mAlertView show];
    msgStr = @"input pin...";
}

-(void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    NSString *aTitle = msgStr;
    NSLog(@"alertView.title = %@",aTitle);
    if ([aTitle isEqualToString:@"Please set amount"]) {
        if (buttonIndex==0) {
            UITextField *textFieldAmount =  [alertView textFieldAtIndex:0];
            NSString *inputAmount = [textFieldAmount text];
            NSLog(@"textFieldAmount = %@",inputAmount);
            
            self.lableAmount.text = [NSString stringWithFormat:@"$%@", [self checkAmount:inputAmount]];
            [pos setAmount:inputAmount aAmountDescribe:@"123" currency:_currencyCode transactionType:mTransType];
            
            self.amount = [NSString stringWithFormat:@"%@", [self checkAmount:inputAmount]];
            self.cashbackAmount = @"123";
        }else{
            [pos cancelSetAmount];
            
        }
        
    }else if ([aTitle isEqualToString:@"Confirm amount"]){
        if (buttonIndex==0) {
            [pos finalConfirm:YES];
        }else{
            [pos finalConfirm:NO];
        }
        
    }else if ([aTitle isEqualToString:@"Online process requested."]){
        [pos isServerConnected:YES];
        
    }else if ([aTitle isEqualToString:@"Request data to server."]){
        //Send the ARPC returned by the bank to pos via this API
        //transaction success: [pos sendOnlineProcessResult:[@"8A023030" stringByAppendingFormat:@"ARPC data return by bank]];
        //transaction fail: [pos sendOnlineProcessResult:[@"8A023035" stringByAppendingFormat:@"ARPC data return by bank]];
        [pos sendOnlineProcessResult:@"8A023030"];
        
        
    }else if ([aTitle isEqualToString:@"Transaction Result"]){
        
    }else if ([aTitle isEqualToString:@"input pin..."]) {
        if (buttonIndex==0) {
            UITextField *textFieldAmount =  [alertView textFieldAtIndex:0];
            NSString *pinStr = [textFieldAmount text];
            NSLog(@"pinStr = %@",pinStr);
            [pos sendPinEntryResult:pinStr];
        }else{
            [pos cancelPinEntry];
        }
    }
    [self hideAlertView];
}

-(void) onRequestFinalConfirm{
    NSLog(@"onRequestFinalConfirm-------amount = %@",amount);
    NSString *msg = [NSString stringWithFormat:@"Amount: $%@",self.amount];
    mAlertView = [[UIAlertView new]
                  initWithTitle:@"Confirm amount"
                  message:msg
                  delegate:self
                  cancelButtonTitle:@"Confirm"
                  otherButtonTitles:@"Cancel",
                  nil ];
    [mAlertView show];
    msgStr = @"Confirm amount";
}

// Prompt user to insert/swipe/tap card
-(void) onRequestWaitingUser{
    self.textViewLog.text  =@"Please insert/swipe/tap card now.";
}

//return NFC and swipe card data on this function.
-(void) onDoTradeResult: (DoTradeResult)result DecodeData:(NSDictionary*)decodeData{
    NSLog(@"onDoTradeResult?>> result %ld",(long)result);
    if (result == DoTradeResult_NONE) {
        self.textViewLog.text = @"No card detected. Please insert or swipe card again and press check card.";
        [pos doTrade:30];
    }else if (result==DoTradeResult_ICC) {
        self.textViewLog.text = @"ICC Card Inserted";
        //Use this API to activate chip card transactions
        [pos doEmvApp:EmvOption_START];
    }else if(result==DoTradeResult_NOT_ICC){
        self.textViewLog.text = @"Card Inserted (Not ICC)";
    }else if(result==DoTradeResult_MCR){
        NSString *maskedPAN = [NSString stringWithFormat:@"Masked PAN: %@\n",decodeData[@"maskedPAN"]];
        NSString *formatID = [NSString stringWithFormat:@"Format ID: %@\n",decodeData[@"formatID"]] ;
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
        NSString *msg = [NSString stringWithFormat:@"Card Swiped:\n"];
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
        NSString *pinBlock = [NSString stringWithFormat:@"pinBlock: %@\n",decodeData[@"pinblock"]];
        NSString *encPAN = [NSString stringWithFormat:@"encPAN: %@\n",decodeData[@"encPAN"]];
        NSString *msg = [NSString stringWithFormat:@"Tap Card:\n"];
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
        
        dispatch_async(dispatch_get_main_queue(),  ^{
            NSDictionary *mDic = [pos getNFCBatchData];
            NSString *tlv;
            if(mDic !=nil){
                tlv= [NSString stringWithFormat:@"NFCBatchData: %@\n",mDic[@"tlv"]];
                NSLog(@"--------nfc:tlv%@",tlv);
            }else{
                tlv = @"";
            }
            
            self.textViewLog.backgroundColor = [UIColor greenColor];
            [self playAudio];
            AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);
            self.textViewLog.text = [msg stringByAppendingString:tlv];
            self.lableAmount.text = @"";
        });
        
    }else if(result==DoTradeResult_NFC_DECLINED){
        self.textViewLog.text = @"Tap Card Declined";
    }else if (result==DoTradeResult_NO_RESPONSE){
        self.textViewLog.text = @"Check card no response";
    }else if(result==DoTradeResult_BAD_SWIPE){
        self.textViewLog.text = @"Bad Swipe. \nPlease swipe again and press check card.";
    }else if(result==DoTradeResult_NO_UPDATE_WORK_KEY){
        self.textViewLog.text = @"device not update work key";
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
    [pos sendTime:_terminalTime];
}

//Prompt message
-(void) onRequestDisplay: (Display)displayMsg{
    NSString *msg = @"";
    if (displayMsg==Display_CLEAR_DISPLAY_MSG) {
        msg = @"";
    }else if(displayMsg==Display_PLEASE_WAIT){
        msg = @"Please wait...";
    }else if(displayMsg==Display_REMOVE_CARD){
        msg = @"Please remove card";
    }else if (displayMsg==Display_TRY_ANOTHER_INTERFACE){
        msg = @"Please try another interface";
    }else if (displayMsg == Display_TRANSACTION_TERMINATED){
        msg = @"Terminated";
    }else if (displayMsg == Display_PIN_OK){
        msg = @"Pin ok";
    }else if (displayMsg == Display_INPUT_PIN_ING){
        msg = @"please input pin on pos";
    }else if (displayMsg == Display_MAG_TO_ICC_TRADE){
        msg = @"please insert chip card on pos";
    }else if (displayMsg == Display_INPUT_OFFLINE_PIN_ONLY){
        msg = @"please input offline pin only";
    }else if(displayMsg == Display_CARD_REMOVED){
        msg = @"Card Removed";
    }else if (displayMsg == Display_INPUT_LAST_OFFLINE_PIN){
        msg = @"please input last offline pin";
    }
    self.textViewLog.text = msg;
}

//Multiple AIDS options
-(void) onRequestSelectEmvApp: (NSArray*)appList{
    mActionSheet = [[UIActionSheet new] initWithTitle:@"Please select app" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil, nil];
    
    for (int i=0 ; i<[appList count] ; i++){
        NSString *emvApp = [appList objectAtIndex:i];
        [mActionSheet addButtonWithTitle:emvApp];
    }
    [mActionSheet addButtonWithTitle:@"Cancel"];
    [mActionSheet setCancelButtonIndex:[appList count]];
    [mActionSheet showInView:[UIApplication sharedApplication].keyWindow];
    msgStr=@"Please select app";
}

//return chip card tlv data on this function
-(void) onRequestOnlineProcess: (NSString*) tlv{
    NSLog(@"onRequestOnlineProcess = %@",[[QPOSService sharedInstance] anlysEmvIccData:tlv]);
    NSDictionary *dict = [DecryptTLV decryptTLVToDict:tlv];
    NSString *C0 = [dict objectForKey:@"C0"];
    NSString *C2 = [dict objectForKey:@"C2"];
 
    NSString *msg = @"Replied success.";
    msgStr = @"Request data to server.";
    mAlertView = [[UIAlertView new]
                  initWithTitle:@"Request data to server."
                  message:msg
                  delegate:self
                  cancelButtonTitle:@"Confirm"
                  otherButtonTitles:nil,
                  nil ];
    [mAlertView show];
}

-(void) onRequestIsServerConnected{
    NSString *msg = @"Replied connected.";
    msgStr = @"Online process requested.";
    [self conductEventByMsg:msgStr];
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
    }
    
    mAlertView = [[UIAlertView new]
                  initWithTitle:@"Transaction Result"
                  message:messageTextView
                  delegate:self
                  cancelButtonTitle:@"Confirm"
                  otherButtonTitles:nil,
                  nil ];
    [mAlertView show];
    self.amount = @"";
    self.cashbackAmount = @"";
    self.lableAmount.text = @"";
    msgStr = @"Transaction Result";
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
    self.textViewLog.backgroundColor = [UIColor whiteColor];
    self.textViewLog.text = @"reset pos ... ";
    if ([pos resetPosStatus]) {
       self.textViewLog.text = @"reset pos success!";
    }else{
       self.textViewLog.text = @"reset pos failed!";
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
}
//get pos id in this function.
- (IBAction)getQposId:(id)sender {
    self.textViewLog.text = @"start ...";
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
}

//get pos info function
- (IBAction)getPosInfo:(id)sender {
      [pos getQPosInfo];
}

//callback function of getPosInfo api.
-(void) onQposInfoResult: (NSDictionary*)posInfoData{
    NSLog(@"onQposInfoResult: %@",posInfoData);
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
}

//eg: update TMK api in pos.
-(void)setMasterKey:(NSInteger)keyIndex{
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
}

//eg: update work key in pos.
-(void)updateWorkKey:(NSInteger)keyIndex{
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
    NSLog(@"onRequestUpdateWorkKeyResult %ld",(long)updateInformationResult);
    if (updateInformationResult==UpdateInformationResult_UPDATE_SUCCESS) {
        self.textViewLog.text = @" update workkey Success";
    }else if(updateInformationResult==UpdateInformationResult_UPDATE_FAIL){
        self.textViewLog.text =  @"Failed";
    }else if(updateInformationResult==UpdateInformationResult_UPDATE_PACKET_LEN_ERROR){
        self.textViewLog.text =  @"Packet len error";
    }else if(updateInformationResult==UpdateInformationResult_UPDATE_PACKET_VEFIRY_ERROR){
        self.textViewLog.text =  @"Packet vefiry error";
    }
}

//eg: use emv_app.bin and emv_capk.bin file to update emv configure in pos,Update time is about two minutes
-(void)UpdateEmvCfg{
    NSString *emvAppCfg = [QPOSUtil byteArray2Hex:[self readLine:@"emv_app"]];
    NSString *emvCapkCfg = [QPOSUtil byteArray2Hex:[self readLine:@"emv_capk"]];
    [pos updateEmvConfig:emvAppCfg emvCapk:emvCapkCfg];
}

// callback function of updateEmvConfig api.
-(void)onReturnCustomConfigResult:(BOOL)isSuccess config:(NSString*)resutl{
    if(isSuccess){
        self.textViewLog.text = @"Success";
        self.textViewLog.backgroundColor = [UIColor greenColor];
    }else{
        self.textViewLog.text =  @"Failed";
    }
    NSLog(@"result: %@",resutl);
}

// update ipek function
- (void)updateIpek{
     [pos doUpdateIPEKOperation:@"00" tracksn:@"00000510F462F8400004" trackipek:@"293C2D8B1D7ABCF83E665A7C5C6532C9" trackipekCheckValue:@"93906AA157EE2604" emvksn:@"00000510F462F8400004" emvipek:@"293C2D8B1D7ABCF83E665A7C5C6532C9" emvipekcheckvalue:@"93906AA157EE2604" pinksn:@"00000510F462F8400004" pinipek:@"293C2D8B1D7ABCF83E665A7C5C6532C9" pinipekcheckValue:@"93906AA157EE2604" block:^(BOOL isSuccess, NSString *stateStr) {
        if (isSuccess) {
            self.textViewLog.text = stateStr;
        }
    }];
}

// update pos firmware api
- (void)updatePosFirmware:(UIButton *)sender {
    NSData *data = [self readLine:@"A27CAYC_S1_master"];//read a14upgrader.asc
    if (data != nil) {
        NSInteger flag = [[QPOSService sharedInstance] updatePosFirmware:data address:self.bluetoothAddress];
        if (flag==-1) {
            [self.textViewLog setText:@"Pos is not plugged in"];
            return;
        }
        
        dispatch_async(dispatch_queue_create(0, 0), ^{
            
            while (true) {
                [NSThread sleepForTimeInterval:0.1];
                NSInteger progress = [pos getUpdateProgress];
                if (progress < 100) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.textViewLog.text = [NSString stringWithFormat:@"%ld%%",(long)progress];
                    });
                    continue;
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.textViewLog.text = @"update completed";
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
    if (updateInformationResult==UpdateInformationResult_UPDATE_SUCCESS) {
        self.textViewLog.text = @"Success";
    }else if(updateInformationResult==UpdateInformationResult_UPDATE_FAIL){
        self.textViewLog.text =  @"Failed";
    }else if(updateInformationResult==UpdateInformationResult_UPDATE_PACKET_LEN_ERROR){
        self.textViewLog.text =  @"Packet len error";
    }else if(updateInformationResult==UpdateInformationResult_UPDATE_PACKET_VEFIRY_ERROR){
        self.textViewLog.text =  @"Packer vefiry error";
    }else{
        self.textViewLog.text = @"firmware updating...";
    }
}

-(void) onGetPosComm:(NSInteger)mode amount:(NSString *)amt posId:(NSString*)aPosId{
    if(mode == 1){
        [pos doTrade:30];
    }
}

#pragma mark - UIAlertView
#pragma mark 改写原有的confrim 绑定的方法

-(void)conductEventByMsg:(NSString *)msg{
    if ([msg isEqualToString:@"Online process requested."]){
        [pos isServerConnected:YES];
    }else if ([msg isEqualToString:@"Request data to server."]){
        [pos sendOnlineProcessResult:@"8A023030"];
    }else if ([msg isEqualToString:@"Transaction Result"]){
        
    }
}

- (void)hideAlertView{
    NSLog(@"hideAlertView");
    [mAlertView dismissWithClickedButtonIndex:0 animated:YES];
}


#pragma mark - UIActionSheet
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    NSString *aTitle = msgStr;
    NSInteger cancelIndex = actionSheet.cancelButtonIndex;
    NSLog(@"selectEmvApp cancelIndex = %d , index = %d",cancelIndex,buttonIndex);
    if ([aTitle isEqualToString:@"Please select app"]){
        if (buttonIndex==cancelIndex) {
            [pos cancelSelectEmvApp];
        }else{
            [pos selectEmvApp:buttonIndex];
        }
    }
    [mActionSheet dismissWithClickedButtonIndex:0 animated:YES];
}

//update emv app by xml file
- (void)updateEMVCfgByXML{
    
    NSMutableArray *listArr = [NSMutableArray array];
    
    NSArray *emvListArr = [self requestXMLData:EMVAppXMl];
    
    TagApp *tag = emvListArr[4];
    
    NSDictionary *emvDict = [pos EmvAppTag];
    
    for (int i = 0 ; i < emvDict.allKeys.count; i++) {
        
        NSString *key = emvDict.allKeys[i];
        NSString * value = [tag valueForKey:key];
    
        if (value.length != 0) {
            
            NSString *tempStr = [[emvDict valueForKey:key] stringByAppendingString:value];
            
            [listArr addObject:tempStr];
        }
    }
    
    NSLog(@"===%@===数量：%lu",listArr,(unsigned long)listArr.count);
    [pos updateEmvAPP:EMVOperation_update data:listArr block:^(BOOL isSuccess, NSString *stateStr) {
        if (isSuccess) {
            self.textViewLog.text = [NSString stringWithFormat:@"success:%@",stateStr];
        }else{
            NSLog(@"fail:%@",stateStr);
            self.textViewLog.text = [NSString stringWithFormat:@"fail:%@",stateStr];
        }
    }];
}
//update emv capk by xml file
- (void)updateCAPKConfigByXML{
    
    NSArray *capkArr = [self requestXMLData:EMVCapkXMl];
    NSMutableArray *capkTempArr = [NSMutableArray array];
    
    TagCapk *capk = capkArr[1];
    
    if (capk.Rid.length != 0) {
        
        NSString *capkStr1 = [NSString stringWithFormat:@"9F06%@",capk.Rid];
        [capkTempArr addObject:capkStr1];
    }
    if (capk.Public_Key_Index.length != 0) {
        
        NSString *capkStr2 = [NSString stringWithFormat:@"9F22%@",capk.Public_Key_Index];
        [capkTempArr addObject:capkStr2];
    }
    if (capk.Public_Key_Module.length != 0) {
        
        NSString *capkStr3 = [NSString stringWithFormat:@"DF02%@",capk.Public_Key_Module];
        [capkTempArr addObject:capkStr3];
    }
    if (capk.Public_Key_CheckValue.length != 0) {
        
        NSString *capkStr4 = [NSString stringWithFormat:@"DF03%@",capk.Public_Key_CheckValue];
        [capkTempArr addObject:capkStr4];
    }
    if (capk.Pk_exponent.length != 0) {
        
        NSString *capkStr5 = [NSString stringWithFormat:@"DF04%@",capk.Pk_exponent];
        [capkTempArr addObject:capkStr5];
    }
    if (capk.Expired_date.length != 0) {
        
        NSString *capkStr6 = [NSString stringWithFormat:@"c%@",capk.Expired_date];
        [capkTempArr addObject:capkStr6];
    }
    if (capk.Hash_algorithm_identification.length != 0) {
        
        NSString *capkStr7 = [NSString stringWithFormat:@"DF06%@",capk.Hash_algorithm_identification];
        [capkTempArr addObject:capkStr7];
    }
    if (capk.Pk_algorithm_identification.length != 0) {
        
        NSString *capkStr8 = [NSString stringWithFormat:@"DF07%@",capk.Pk_algorithm_identification];
        [capkTempArr addObject:capkStr8];
    }
    
    [pos updateEmvCAPK:EMVOperation_update data:capkTempArr.copy block:^(BOOL isSuccess, NSString *stateStr) {
        if (isSuccess) {
            self.textViewLog.text = [NSString stringWithFormat:@"success:%@",stateStr];
            
        }else{
            
            NSLog(@"fail:%@",stateStr);
            self.textViewLog.text = [NSString stringWithFormat:@"fail:%@",stateStr];
        }
    }];
}

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
    
    NSLog(@"tradeAmount = %@",tradeAmount);
    if (tradeAmount==nil || [tradeAmount isEqualToString:@""]) {
        return rs;
    }

    if ([tradeAmount hasPrefix:@"0"]) {
        return rs;
    }
    
    if (![QPOSUtil isPureInt:tradeAmount]) {
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
    NSLog(@"trade amount = %@",rs);
    return rs;
}

- (NSData*)readLine:(NSString*)name
{
    NSString* binFile = [[NSBundle mainBundle]pathForResource:name ofType:@".bin"];
    NSString* ascFile = [[NSBundle mainBundle]pathForResource:name ofType:@".asc"];
    //NSLog(@"[%@]-- [%@]",name,ascFile);
    if (binFile!= nil && ![binFile isEqualToString: @""]) {
        NSFileManager* Manager = [NSFileManager defaultManager];
        NSData* data1 = [[NSData alloc] init];
        data1 = [Manager contentsAtPath:binFile];
        return data1;
    }else if (ascFile!= nil && ![ascFile isEqualToString: @""]){
        NSFileManager* Manager = [NSFileManager defaultManager];
        NSData* data2 = [[NSData alloc] init];
        data2 = [Manager contentsAtPath:ascFile];
        //NSLog(@"----------");
        return data2;
    }
    return nil;
}

- (void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

