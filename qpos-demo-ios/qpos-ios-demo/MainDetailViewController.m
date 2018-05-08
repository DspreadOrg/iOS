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
#import "Util.h"
#import "Print.h"

@interface MainDetailViewController ()
- (void)configureView;
@property (weak, nonatomic) IBOutlet UILabel *updateProgressLab;
@property (nonatomic,copy)NSString *terminalTime;
@property (nonatomic,copy)NSString *currencyCode;
@property (weak, nonatomic) IBOutlet UILabel *labSDK;
@property (weak, nonatomic) IBOutlet UIButton *btnStart;
@property (weak, nonatomic) IBOutlet UIButton *btnGetPosId;
@property (weak, nonatomic) IBOutlet UIButton *btnGetPosInfo;
@property (weak, nonatomic) IBOutlet UIButton *btnDisconnect;
@property (weak, nonatomic) IBOutlet UIButton *btnResetPos;
@property (weak, nonatomic) IBOutlet UIButton *btnIsCardExist;
@property (nonatomic,strong) NSData* apduStr;
@property (weak, nonatomic) IBOutlet UIButton *btnUpdateEmvCfg;

@end

@implementation MainDetailViewController{
    QPOSService *pos;
    UIAlertView *mAlertView;
    UIActionSheet *mActionSheet;
    PosType     mPosType;
    dispatch_queue_t self_queue;
    TransactionType mTransType;
    NSString *msgStr;
    BOOL doTradeByEnterAmount;
    UIProgressView* progressView;
    NSTimer* appearTimer;
    NSTimer* sendTimer;
    float _updateProgress;
}

@synthesize bluetoothAddress;
@synthesize amount;
@synthesize cashbackAmount;

#pragma mart - sdk delegate

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
    
    if (![Util isPureInt:tradeAmount]) {
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
- (IBAction)getQposId:(id)sender {
    self.textViewLog.text = @"start ...";
    [pos getQPosId];


}

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
    
    self.textViewLog.text = aStr;
    
   
    //    dispatch_async(dispatch_get_main_queue(),  ^{
    //        NSDateFormatter *dateFormatter = [NSDateFormatter new];
    //        [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    //        _terminalTime = [dateFormatter stringFromDate:[NSDate date]];
    //        mTransType = TransactionType_GOODS;
    //        _currencyCode = @"156";
    //        [pos doTrade:30];
    //    });
}

-(void) onRequestWaitingUser{
    self.textViewLog.text  =@"Please insert/swipe/tap card now.";
}
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
    }else if (errorState == DHError_QPOS_MEMORY_OVERFLOW){
        msg = @"QPOS memory overflow.Pls clear the trade log";
    }
    
    self.textViewLog.text = msg;
    NSLog(@"onError = %@",msg);
}


//开始执行start 按钮后返回的结果状态
-(void) onDoTradeResult: (DoTradeResult)result DecodeData:(NSDictionary*)decodeData{
    NSLog(@"onDoTradeResult?>> result %ld",(long)result);
    if (result == DoTradeResult_NONE) {
        self.textViewLog.text = @"No card detected. Please insert or swipe card again and press check card.";
        [pos doTrade:30];
    }else if (result==DoTradeResult_ICC) {
        self.textViewLog.text = @"ICC Card Inserted";
        [pos doEmvApp:EmvOption_START];
    }else if(result==DoTradeResult_NOT_ICC){
        self.textViewLog.text = @"Card Inserted (Not ICC)";
    }else if(result==DoTradeResult_MCR){
        //        [pos getCardNo]
        NSLog(@"decodeData: %@",decodeData);
        NSString *formatID = [NSString stringWithFormat:@"Format ID: %@\n",decodeData[@"formatID"]] ;
        NSString *maskedPAN = [NSString stringWithFormat:@"Masked PAN: %@\n",decodeData[@"maskedPAN"]];
        NSString *expiryDate = [NSString stringWithFormat:@"Expiry Date: %@\n",decodeData[@"expiryDate"]];
        NSString *cardHolderName = [NSString stringWithFormat:@"Cardholder Name: %@\n",decodeData[@"cardholderName"]];
        //NSString *ksn = [NSString stringWithFormat:@"KSN: %@\n",decodeData[@"ksn"]];
        NSString *serviceCode = [NSString stringWithFormat:@"Service Code: %@\n",decodeData[@"serviceCode"]];
        //NSString *track1Length = [NSString stringWithFormat:@"Track 1 Length: %@\n",decodeData[@"track1Length"]];
        //NSString *track2Length = [NSString stringWithFormat:@"Track 2 Length: %@\n",decodeData[@"track2Length"]];
        //NSString *track3Length = [NSString stringWithFormat:@"Track 3 Length: %@\n",decodeData[@"track3Length"]];
        //NSString *encTracks = [NSString stringWithFormat:@"Encrypted Tracks: %@\n",decodeData[@"encTracks"]];
        NSString *encTrack1 = [NSString stringWithFormat:@"Encrypted Track 1: %@\n",decodeData[@"encTrack1"]];
        NSString *encTrack2 = [NSString stringWithFormat:@"Encrypted Track 2: %@\n",decodeData[@"encTrack2"]];
        NSString *encTrack3 = [NSString stringWithFormat:@"Encrypted Track 3: %@\n",decodeData[@"encTrack3"]];
        //NSString *partialTrack = [NSString stringWithFormat:@"Partial Track: %@",decodeData[@"partialTrack"]];
        NSString *pinKsn = [NSString stringWithFormat:@"PIN KSN: %@\n",decodeData[@"pinKsn"]];
        NSString *trackksn = [NSString stringWithFormat:@"Track KSN: %@\n",decodeData[@"trackksn"]];
        NSString *pinBlock = [NSString stringWithFormat:@"pinBlock: %@\n",decodeData[@"pinblock"]];
        NSString *encPAN = [NSString stringWithFormat:@"encPAN: %@\n",decodeData[@"encPAN"]];
        
        NSString *msg = [NSString stringWithFormat:@"Card Swiped:\n"];
        msg = [msg stringByAppendingString:formatID];
        msg = [msg stringByAppendingString:maskedPAN];
        msg = [msg stringByAppendingString:expiryDate];
        msg = [msg stringByAppendingString:cardHolderName];
        //msg = [msg stringByAppendingString:ksn];
        msg = [msg stringByAppendingString:pinKsn];
        msg = [msg stringByAppendingString:trackksn];
        msg = [msg stringByAppendingString:serviceCode];
        
        msg = [msg stringByAppendingString:encTrack1];
        msg = [msg stringByAppendingString:encTrack2];
        msg = [msg stringByAppendingString:encTrack3];
        msg = [msg stringByAppendingString:pinBlock];
        msg = [msg stringByAppendingString:encPAN];
        self.textViewLog.backgroundColor = [UIColor greenColor];
        [self playAudio];
        AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);
        self.textViewLog.text = msg;
        self.lableAmount.text = @"";
          [[NSUserDefaults standardUserDefaults]setObject:msg forKey:@"swipeData"];
        
//        [pos buildPinBlock:@"2632C5C0EAC64536D3C55EBCF76704DA" workKeyCheck:@"0000000000000000" encryptType:1 keyIndex:4 maxLen:6 typeFace:@"pls input pin" cardNo:maskedPAN date:@"20171213" delay:30];
       
        

        //        dispatch_async(dispatch_get_main_queue(),  ^{
        //            [pos calcMacDouble:@"12345678123456781234567812345678"];
        //         });
    }else if(result==DoTradeResult_NFC_OFFLINE || result == DoTradeResult_NFC_ONLINE){
        
//      NSDictionary *a =  [pos getICCTag:1 tagCount:1 tagArrStr:@"9F6B"];
//      NSDictionary *b =  [pos getICCTag:1 tagCount:1 tagArrStr:@"57"];
//    NSDictionary *c = [pos getICCTag:EncryptType_encrypted cardType:2 tagCount:1 tagArrStr:@"57"];
        NSLog(@"decodeData: %@",decodeData);
        NSString *formatID = [NSString stringWithFormat:@"Format ID: %@\n",decodeData[@"formatID"]] ;
        NSString *maskedPAN = [NSString stringWithFormat:@"Masked PAN: %@\n",decodeData[@"maskedPAN"]];
        NSString *expiryDate = [NSString stringWithFormat:@"Expiry Date: %@\n",decodeData[@"expiryDate"]];
        NSString *cardHolderName = [NSString stringWithFormat:@"Cardholder Name: %@\n",decodeData[@"cardholderName"]];
        //NSString *ksn = [NSString stringWithFormat:@"KSN: %@\n",decodeData[@"ksn"]];
        NSString *serviceCode = [NSString stringWithFormat:@"Service Code: %@\n",decodeData[@"serviceCode"]];
        //NSString *track1Length = [NSString stringWithFormat:@"Track 1 Length: %@\n",decodeData[@"track1Length"]];
        //NSString *track2Length = [NSString stringWithFormat:@"Track 2 Length: %@\n",decodeData[@"track2Length"]];
        //NSString *track3Length = [NSString stringWithFormat:@"Track 3 Length: %@\n",decodeData[@"track3Length"]];
        //NSString *encTracks = [NSString stringWithFormat:@"Encrypted Tracks: %@\n",decodeData[@"encTracks"]];
        NSString *encTrack1 = [NSString stringWithFormat:@"Encrypted Track 1: %@\n",decodeData[@"encTrack1"]];
        NSString *encTrack2 = [NSString stringWithFormat:@"Encrypted Track 2: %@\n",decodeData[@"encTrack2"]];
        NSString *encTrack3 = [NSString stringWithFormat:@"Encrypted Track 3: %@\n",decodeData[@"encTrack3"]];
        //NSString *partialTrack = [NSString stringWithFormat:@"Partial Track: %@",decodeData[@"partialTrack"]];
        NSString *pinKsn = [NSString stringWithFormat:@"PIN KSN: %@\n",decodeData[@"pinKsn"]];
        NSString *trackksn = [NSString stringWithFormat:@"Track KSN: %@\n",decodeData[@"trackksn"]];
        NSString *pinBlock = [NSString stringWithFormat:@"pinBlock: %@\n",decodeData[@"pinblock"]];
        NSString *encPAN = [NSString stringWithFormat:@"encPAN: %@\n",decodeData[@"encPAN"]];
        
        NSString *msg = [NSString stringWithFormat:@"Tap Card:\n"];
        msg = [msg stringByAppendingString:formatID];
        msg = [msg stringByAppendingString:maskedPAN];
        msg = [msg stringByAppendingString:expiryDate];
        msg = [msg stringByAppendingString:cardHolderName];
        //msg = [msg stringByAppendingString:ksn];
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
            
            NSDictionary* mDict = [pos getICCTag:@"0" cardType:1 tagCount:0 tagArrStr:@""];
            NSString *tlv;
            if(mDic !=nil){
                tlv= [NSString stringWithFormat:@"NFCBatchData: %@\n",mDic[@"tlv"]];
            }else{
                tlv = @"";
            }
            
            self.textViewLog.backgroundColor = [UIColor greenColor];
            [self playAudio];
            AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);
            self.textViewLog.text = [msg stringByAppendingString:tlv];
            self.lableAmount.text = @"";
            NSLog(@"msg == %@",msg);
            
//            [pos getICCTag:1 tagCount:1 tagArrStr:@"9F6B"];
        });
        
    }else if(result==DoTradeResult_NFC_DECLINED){
        self.textViewLog.text = @"Tap Card Declined";
    }else if (result==DoTradeResult_NO_RESPONSE){
        self.textViewLog.text = @"Check card no response";
    }else if(result==DoTradeResult_BAD_SWIPE){
        self.textViewLog.text = @"Bad Swipe. \nPlease swipe again and press check card.";
        
//        [pos doTrade:30];
    }else if(result==DoTradeResult_NO_UPDATE_WORK_KEY){
        self.textViewLog.text = @"device not update work key";
    }
    
}
- (void)playAudio
{
    if(![self.bluetoothAddress isEqualToString:@"audioType"]){
        
        SystemSoundID soundID;
        NSString *strSoundFile = [[NSBundle mainBundle] pathForResource:@"1801" ofType:@"wav"];
        AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:strSoundFile],&soundID);
        AudioServicesPlaySystemSound(soundID);
    }
}

//输入金额
-(void) onRequestSetAmount{
    
    if (doTradeByEnterAmount) {
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
    }else{
        self.amount = @"1";
        _lableAmount.text = @"$100";
        [pos setAmount:self.amount aAmountDescribe:@"1000" currency:@"156" transactionType:TransactionType_GOODS];
    }
  
}
//
-(void) onRequestSelectEmvApp: (NSArray*)appList{
    //NSString *resultStr = @"";
    
    mActionSheet = [[UIActionSheet new] initWithTitle:@"Please select app" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil, nil];
    
    for (int i=0 ; i<[appList count] ; i++){
        NSString *emvApp = [appList objectAtIndex:i];
        [mActionSheet addButtonWithTitle:emvApp];
        
        //resultStr = [NSString stringWithFormat:@"%@[%@] ", resultStr,emvApp];
    }
    [mActionSheet addButtonWithTitle:@"Cancel"];
    [mActionSheet setCancelButtonIndex:[appList count]];
    [mActionSheet showInView:[UIApplication sharedApplication].keyWindow];
    
    //NSLog(@"resultStr: %@",resultStr);
    
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
-(void) onRequestTime{
    NSString*formatStringForHours = [NSDateFormatter dateFormatFromTemplate:@"j" options:0 locale:[NSLocale currentLocale]];
    NSRange containsA =[formatStringForHours rangeOfString:@"a"];
    BOOL hasAMPM =containsA.location != NSNotFound;
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
-(void) onRequestIsServerConnected{
    
    
    NSString *msg = @"Replied connected.";
    msgStr = @"Online process requested.";
    
    [self conductEventByMsg:msgStr];
    
    //    mAlertView = [[UIAlertView new]
    //                  initWithTitle:@"Online process requested."
    //                  message:msg
    //                  delegate:self
    //                  cancelButtonTitle:@"Confirm"
    //                  otherButtonTitles:nil,
    //                  nil ];
    
    //    [mAlertView show];
    
    
}

//Request data to server
-(void) onPinKeyTDESResult:(NSString *)encPin{
    NSLog(@"onPinKeyTDESResult: %@",encPin);
    NSString *msg = @"Replied success.";
    
    msgStr = @"Request data to server.";
    [self conductEventByMsg:msgStr];
    
    //        mAlertView = [[UIAlertView new]
    //                      initWithTitle:@"Request data to server."
    //                      message:msg
    //                      delegate:self
    //                      cancelButtonTitle:@"Confirm"
    //                      otherButtonTitles:nil,
    //                      nil ];
    //        [mAlertView show];
    
}

//回调成功的alert
-(void) onRequestOnlineProcess: (NSString*) tlv{
    
    NSLog(@"tlv == %@",tlv);
    NSLog(@"onRequestOnlineProcess =**** %@",[[QPOSService sharedInstance] anlysEmvIccData:tlv]);
    
    [[NSUserDefaults standardUserDefaults]setObject:tlv forKey:@"iccData"];
//       NSDictionary *dictDF21 = [pos getICCTag:0 tagCount:1 tagArrStr:@"DF21"];
//        NSDictionary *dict9F33 = [pos getICCTag:0 tagCount:1 tagArrStr:@"9F33"];
//      NSDictionary *dict9F34 = [pos getICCTag:0 tagCount:1 tagArrStr:@"9F34"];
//       NSDictionary *cd = [pos getICCTag:EncryptType_encrypted cardType:2 tagCount:1 tagArrStr:@"57"];
//
//        NSDictionary *dict9F66 = [pos getICCTag:0 tagCount:1 tagArrStr:@"9F66"];
    //    [self claMac];
    //    [self batchSendAPDU];
    //    [pos calcMacDouble_all:@"12345678123456781234567812345678" keyIndex:0 delay:5];
    //    [pos pinKey_TDES_all:0 pin:@"1122334455667788" delay:5];
    
 

//    
    NSString *msg = @"Replied success.";
    msgStr = @"Request data to server.";
    [self conductEventByMsg:msgStr];
    
    
    mAlertView = [[UIAlertView new]
                  initWithTitle:@"Request data to server."
                  message:msg
                  delegate:self
                  cancelButtonTitle:@"Confirm"
                  otherButtonTitles:nil,
                  nil ];
    [mAlertView show];
    
    
}
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
}
-(void) onRequestTransactionLog: (NSString*)tlv{
    NSLog(@"onTransactionLog %@",tlv);
}
-(void) onRequestBatchData: (NSString*)tlv{
    NSLog(@"onBatchData %@",tlv);
    tlv = [@"batch data:\n" stringByAppendingString:tlv];
    self.textViewLog.text = tlv;
}

-(void) onReturnReversalData: (NSString*)tlv{
    NSLog(@"onReversalData %@",tlv);
    tlv = [@"reversal data:\n" stringByAppendingString:tlv];
    self.textViewLog.text = tlv;
}

-(void)onAsyncResetPosStatus:(BOOL)isReset{
    if (isReset) {
        self.textViewLog.text = @"reset qpos success";
    }else{
        self.textViewLog.text = @"reset pos fail";
    }
    
}

//pos 连接成功的回调
-(void) onRequestQposConnected{
    NSLog(@"onRequestQposConnected");
    if ([self.bluetoothAddress  isEqual: @"audioType"]) {
        self.textViewLog.text = @"AudioType connected.";
       
    }else{
        self.textViewLog.text = @"Bluetooth connected.";
//        [self sleepMs:500];
//        [pos getQPosInfo];

    }
    
}
- (IBAction)disconnect:(id)sender {
    [pos disconnectBT];
}
//pos  连接失败的回调
-(void) onRequestQposDisconnected{
    NSLog(@"onRequestQposDisconnected");
    self.textViewLog.text = @"pos disconnected.";
    
}
//没有创建连接的回调
-(void) onRequestNoQposDetected{
    NSLog(@"onRequestNoQposDetected");
    self.textViewLog.text = @"No pos detected.";
    
}

-(void) onRequestDisplay: (Display)displayMsg{
    NSLog(@"onRequestDisplay");
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
        msg = @"input offline pin only";
    }else if(displayMsg == Display_CARD_REMOVED){
        msg = @"Card Removed";
    }
    self.textViewLog.text = msg;
}
-(void) onReturnGetPinResult:(NSDictionary*)decodeData{
    NSString *aStr = @"encryptMode: ";
    aStr = [aStr stringByAppendingString:decodeData[@"encryptMode"]];
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:@"ksn:"];
    aStr = [aStr stringByAppendingString:decodeData[@"ksn"]];
    aStr = [aStr stringByAppendingString:@"\n"];
    aStr = [aStr stringByAppendingString:@"pinBlock:"];
    aStr = [aStr stringByAppendingString:decodeData[@"pin"]];
    
    self.textViewLog.text = aStr;
}

//add icc apdu 2014-03-11
-(void) onReturnPowerOnIccResult:(BOOL) isSuccess  KSN:(NSString *) ksn ATR:(NSString *)atr ATRLen:(NSInteger)atrLen{
    if (isSuccess) {
        NSString *aStr = @"Power on ICC Success\nksn: ";
        aStr = [aStr stringByAppendingString:ksn];
        
        aStr = [aStr stringByAppendingString:@"\natr: "];
        aStr = [aStr stringByAppendingString:atr];
        aStr = [aStr stringByAppendingString:@"\natrLen: "];
        aStr = [aStr stringByAppendingString:[NSString stringWithFormat:@"%ld",(long)atrLen]];
        self.textViewLog.text = aStr;
        
    }else{
        self.textViewLog.text = @"Power on ICC Failed";
    }
}
-(void) onReturnPowerOffIccResult:(BOOL) isSuccess{
    if (isSuccess) {
        self.textViewLog.text = @"Power off ICC Success";
    }else{
        self.textViewLog.text = @"Power off ICC Failed";
    }
}
-(void) onReturnApduResult:(BOOL)isSuccess APDU:(NSString *)apdu APDU_Len:(NSInteger) apduLen{
    if (isSuccess) {
        NSString *aStr = @"APDU Result: ";
        aStr = [aStr stringByAppendingString:apdu];
        self.textViewLog.text = aStr;
    }else{
        self.textViewLog.text = @"APDU Failed";
    }
}

//add set the sleep time 2014-03-25
-(void)onReturnSetSleepTimeResult:(BOOL)isSuccess{
    if (isSuccess) {
        self.textViewLog.text = @"Set sleep time Success";
    }else{
        self.textViewLog.text = @"Set sleep time Failed";
    }
}

//add 2014-04-11
-(void)onReturnCustomConfigResult:(BOOL)isSuccess config:(NSString*)resutl{
    
    if(isSuccess){
        
        self.textViewLog.text = @"Success";
        self.textViewLog.backgroundColor = [UIColor greenColor];
        self.btnUpdateEmvCfg.enabled = YES;
    }else{
        self.textViewLog.text =  @"Failed";
    }
    NSLog(@"result: %@",resutl);
}


-(void) onRequestGetCardNoResult:(NSString *)result{
    self.textViewLog.text = result;
    NSDictionary *dict5F20 = [pos getICCTag:0 tagCount:1 tagArrStr:@"5F20"];
    
    NSString *cardHolderName = [Util asciiFormatString:[Util HexStringToByteArray:@"51492F434849"]];
    
    NSDictionary *dict5F24 = [pos getICCTag:0 tagCount:1 tagArrStr:@"5F24"];
    
    NSDictionary *dict5A = [pos getICCTag:0 tagCount:1 tagArrStr:@"5A"];
    
//    [pos pinKey_TDES_all:0 Pan:@"6217850800011191689" Pin:@"1111" TimeOut:5];
}


-(void) onRequestPinEntry{
    NSLog(@"onRequestPinEntry");
    NSString *msg = @"";
    mAlertView = [[UIAlertView new]
                  initWithTitle:@"Please set pin"
                  message:msg
                  delegate:self
                  cancelButtonTitle:@"Confirm"
                  otherButtonTitles:@"Cancel",
                  nil ];
    [mAlertView setAlertViewStyle:UIAlertViewStyleSecureTextInput];
    //UIAlertViewStylePlainTextInput
    [mAlertView show];
    
    msgStr = @"Please set pin";
    
}

-(void) onReturnSetMasterKeyResult: (BOOL)isSuccess{
    if(isSuccess){
        self.textViewLog.text = @"Success";
    }else{
        self.textViewLog.text =  @"Failed";
    }
    //    NSLog(@"result: %@",resutl);
}

-(void) onRequestUpdateWorkKeyResult:(UpdateInformationResult)updateInformationResult
{
    NSLog(@"onRequestUpdateWorkKeyResult %ld",(long)updateInformationResult);
    if (updateInformationResult==UpdateInformationResult_UPDATE_SUCCESS) {
        self.textViewLog.text = @" update workkey Success";
    }else if(updateInformationResult==UpdateInformationResult_UPDATE_FAIL){
        self.textViewLog.text =  @"Failed";
    }else if(updateInformationResult==UpdateInformationResult_UPDATE_PACKET_LEN_ERROR){
        self.textViewLog.text =  @"Packet len error";
    }
    else if(updateInformationResult==UpdateInformationResult_UPDATE_PACKET_VEFIRY_ERROR){
        self.textViewLog.text =  @"Packet vefiry error";
    }
    
}

-(void) onReturnBatchSendAPDUResult:(NSDictionary *)apduResponses{
    NSLog(@"onBatchApduResponseReceived - apduResponses: %@", apduResponses);
    
    NSArray *keys = [apduResponses allKeys];
    for (NSString *key in keys) {
        _textViewLog.text = [NSString stringWithFormat:@"%@%d:%@\n", _textViewLog.text, [key intValue], [apduResponses objectForKey:key]];
    }
}

-(void) onReturniccCashBack: (NSDictionary*)result{
    NSString *aStr = [@"serviceCode:" stringByAppendingString:result[@"serviceCode"]];
    aStr = [aStr stringByAppendingString:@"\n"];
    NSString *temp = [@"trackblock:" stringByAppendingString:result[@"trackblock"]];
    aStr = [aStr stringByAppendingString:temp];
    self.textViewLog.text = aStr;
    
}

-(void) onLcdShowCustomDisplay: (BOOL)isSuccess{
    if(isSuccess){
        self.textViewLog.text = @"Success";
    }else{
        self.textViewLog.text =  @"Failed";
    }
}

-(void)onRequestCalculateMac:(NSString *)calMacString{
    self.textViewLog.text =calMacString;
    NSLog(@"onRequestCalculateMac %@",calMacString);
    //    NSData *aa = [Util stringFormatTAscii:calMacString];
    //    NSLog(@"aaaaa: %@",[Util byteArray2Hex:aa]);
    NSString *msg = @"Replied success.";
    msgStr = @"Request data to server";
    [self conductEventByMsg:msgStr];
    //    mAlertView = [[UIAlertView new]
    //                  initWithTitle:@"Request data to server."
    //                  message:msg
    //                  delegate:self
    //                  cancelButtonTitle:@"Confirm"
    //                  otherButtonTitles:nil,
    //                  nil ];
    //    [mAlertView show];
}


-(void) onDownloadRsaPublicKeyResult:(NSDictionary *)result{
    NSLog(@"onDownloadRsaPublicKeyResult %@",result);
}

-(void) onGetPosComm:(NSInteger)mode amount:(NSString *)amt posId:(NSString*)aPosId{
    if(mode == 1){
        [pos doTrade:30];
    }
}

- (IBAction)testAlertView:(id)sender {
    //    NSString *msg = @"Replied success.";
    //    mAlertView = [[UIAlertView new]
    //                  initWithTitle:@"Request data to server."
    //                  message:msg
    //                  delegate:self
    //                  cancelButtonTitle:@"Confirm"
    //                  otherButtonTitles:nil,
    //                  nil ];
    //    [mAlertView show];
    
    msgStr = @"Request data to server.";
    [self conductEventByMsg:msgStr];
}

-(void) onEmvICCExceptionData: (NSString*)tlv{
    
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

-(void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    
    NSString *aTitle = msgStr;
    NSLog(@"alertView.title = %@",aTitle);
    if ([aTitle isEqualToString:@"Please set amount"]) {
        if (buttonIndex==0) {
            UITextField *textFieldAmount =  [alertView textFieldAtIndex:0];
            NSString *inputAmount = [textFieldAmount text];
            NSLog(@"textFieldAmount = %@",inputAmount);
            
            self.lableAmount.text = [NSString stringWithFormat:@"$%@", [self checkAmount:inputAmount]];
            [pos setAmount:inputAmount aAmountDescribe:@"Cashback" currency:_currencyCode transactionType:mTransType];
            
            self.amount = [NSString stringWithFormat:@"%@", [self checkAmount:inputAmount]];
            self.cashbackAmount = @"Cashback";
            
            
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
        
        [pos sendOnlineProcessResult:@"8A023030"];
        
    }else if ([aTitle isEqualToString:@"Transaction Result"]){
        
    }else if ([aTitle isEqualToString:@"Please set pin"]) {
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
- (void)willPresentAlertView:(UIAlertView *)alertView {
    //NSLog(@"willPresentAlertView");
}

- (void)hideAlertView{
    NSLog(@"hideAlertView");
    [mAlertView dismissWithClickedButtonIndex:0 animated:YES];
    
    //mAlertView = nil;
}


#pragma mark - UIActionSheet
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    
    NSString *aTitle = @"Please select app";
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
    //mActionSheet = nil;
    
}

/*
 -(void)actionSheetCancel:(UIActionSheet *)actionSheet{
 NSLog(@"actionSheetCancel");
 }
 -(void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex{
 NSLog(@"didDismissWithButtonIndex buttonIndex = %d",buttonIndex);
 }
 -(void)actionSheet:(UIActionSheet *)actionSheet willDismissWithButtonIndex:(NSInteger)buttonInde{
 NSLog(@"willDismissWithButtonIndex buttonInde = %d",buttonInde);
 }
 
 */

#pragma mark - start do trade


- (void)si_one{
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    NSString *dateTimeString = [dateFormatter stringFromDate:[NSDate date]];
    
    NSMutableDictionary *dataDict = [NSMutableDictionary dictionary];
    [dataDict setObject:[NSArray arrayWithObjects:@"FE", dateTimeString, @"00A404000FA0000003334355502D4D4F42494C45", nil] forKey:[NSNumber numberWithInt:1]];
    [dataDict setObject:[NSArray arrayWithObjects:@"FE", dateTimeString, @"80E0000000", nil] forKey:[NSNumber numberWithInt:2]];
    [dataDict setObject:[NSArray arrayWithObjects:@"FE", dateTimeString, @"00D68100404AC0680CDECDF183C0F8435ED4A34F15FE9DF64F7E289A05C0F8435ED4A34F15C0F8435ED4A34F15C0F8435ED4A34F15C0F8435ED4A34F15C0F8435ED4A34F15", nil] forKey:[NSNumber numberWithInt:3]];
    
    [dataDict setObject:[NSArray arrayWithObjects:@"FE", dateTimeString, @"00D682001076DAA738F81683570100FFFFFFFFFFFF", nil] forKey:[NSNumber numberWithInt:4]];//保存csn
    
    [dataDict setObject:[NSArray arrayWithObjects:@"FE", dateTimeString, @"00D683000101", nil] forKey:[NSNumber numberWithInt:5]];
    
    [dataDict setObject:[NSArray arrayWithObjects:@"FE", dateTimeString, @"0084000008", nil] forKey:[NSNumber numberWithInt:6]];//取随机数
    [pos VIPOSBatchSendAPDU:dataDict];
    
}

- (void)si_two{
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    NSString *dateTimeString = [dateFormatter stringFromDate:[NSDate date]];
    
    
    NSMutableDictionary *dataDict = [NSMutableDictionary dictionary];
    [dataDict setObject:[NSArray arrayWithObjects:@"FE", dateTimeString, @"84F402201C1F4FECEB810743F78902013E8763064AC8D95EC3422ADCE00A8B9C1C", nil] forKey:[NSNumber numberWithInt:1]];
    [dataDict setObject:[NSArray arrayWithObjects:@"FE", dateTimeString, @"84F401131C0438BDAA7CB3FF42EFBAA5D10E195E0A404836BDC78DEEBC4B5DA53D", nil] forKey:[NSNumber numberWithInt:2]];
    [dataDict setObject:[NSArray arrayWithObjects:@"FE", dateTimeString, @"84F401141CE20D6208E563CF318B7F5DB2D3C61B373C2654551DC451D52AE3314D", nil] forKey:[NSNumber numberWithInt:3]];
    
    [dataDict setObject:[NSArray arrayWithObjects:@"FE", dateTimeString, @"84F401151CD40BAAB2B507C12925CF6958F1CD9902CF35590A9DBD8F99F386BC12", nil] forKey:[NSNumber numberWithInt:4]];
    
    [dataDict setObject:[NSArray arrayWithObjects:@"FE", dateTimeString, @"84F401161C98CE71278C7060083530B7B61B27B8997936B1907209EDEAB5DF0C80", nil] forKey:[NSNumber numberWithInt:5]];
    
    //    [dataDict setObject:[NSArray arrayWithObjects:@"FE", dateTimeString, @"84F401171CAE6DD1EFB70D1818F272F21B08DAACAB6BD70DED617328AFCF6FF0E8", nil] forKey:[NSNumber numberWithInt:6]];
    
    [dataDict setObject:[NSArray arrayWithObjects:@"FE", dateTimeString, @"8026000000", nil] forKey:[NSNumber numberWithInt:6]];
    [pos VIPOSBatchSendAPDU:dataDict];
    
}

-(void)apduExample{
    NSString *dateTimeString = @"20140517162926";
    [pos doTrade:dateTimeString delay:60];
}

-(void)claMac{
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    NSString *dateTimeString = [dateFormatter stringFromDate:[NSDate date]];
    
    NSMutableDictionary *dataDict = [NSMutableDictionary dictionary];
    [dataDict setObject:[NSArray arrayWithObjects:@"15", @"20140517162926", @"3230313430373032313135353337204444424532413846313333324631393339453439413334304333373142433838203239353141324444353430363441453443314433303130323230303030303046203130303030313031303134303232383030353233800000", nil] forKey:[NSNumber numberWithInt:1]];
    
    [dataDict setObject:[NSArray arrayWithObjects:@"13", @"20140704093650", @"3132333435363738393033333333300030303030303030313139393736333933302E353500000000", nil] forKey:[NSNumber numberWithInt:2]];
    
    NSDictionary *a = [pos synVIPOSBatchSendAPDU:dataDict];
    NSLog(@"claMac--------- %@",a);
}

-(void)batchSendAPDU{
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    NSString *dateTimeString = [dateFormatter stringFromDate:[NSDate date]];
    
    NSMutableDictionary *dataDict = [NSMutableDictionary dictionary];
    [dataDict setObject:[NSArray arrayWithObjects:@"13", @"20140704093650", @"3132333435363738393033333333300030303030303030313139393736333933302E353500000000", nil] forKey:[NSNumber numberWithInt:1]];
    
    NSDictionary *b = [pos synVIPOSBatchSendAPDU:dataDict];
    NSLog(@"batchSendAPDU--------- %@",b);
}

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

-(void)setMasterKey:(NSInteger)keyIndex{
    NSString *pik = @"89EEF94D28AA2DC189EEF94D28AA2DC1";//111111111111111111111111
    NSString *pikCheck = @"82E13665B4624DF5";
    
    pik = @"F679786E2411E3DEF679786E2411E3DE";//33333333333333333333333333333
    pikCheck = @"ADC67D8473BF2F06";
    [pos setMasterKey:pik checkValue:pikCheck keyIndex:keyIndex];
}

-(void)UpdateEmvCfg{
    NSString *emvAppCfg = [Util byteArray2Hex:[self readLine:@"emvcfg_app"]];
    NSString *emvCapkCfg = [Util byteArray2Hex:[self readLine:@"emvcfg_capk"]];
    [pos updateEmvConfig:emvAppCfg emvCapk:emvCapkCfg];
}
- (IBAction)updateEmvCfg:(id)sender {
//    NSString *emvAppCfg = [Util byteArray2Hex:[self readLine:@"kernel_app_"]];
//    NSString *emvCapkCfg = [Util byteArray2Hex:[self readLine:@"capk_"]];
//    
//    [pos updateEmvConfig:emvAppCfg emvCapk:emvCapkCfg];
   // NSString *emvAppCfg = @"0000000000000000000000000000000000000000000000000000f4f0f0faaffe8000010f00000000753000000000c350000000009c400000000003e8b6000000000003e8012260d8c8ff80f0300100000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000fc50a820000400000000f850a8f8001432000013880000000000f4f0f0faaffe8000010f00000000753000000000c350000000009c400000000003e8b6000000000003e8012260d8c8ff80f03001a0000003330101000000000000000000070020050012345678901234424354455354203132333435363738616263640000000000000000000000015600015600015638333230314943434e4c2d475037333003039f37040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009f0802000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010e0000fc78fcf8f00010000000fc78fcf8f01432000013880000000000f4f0f0faaffe8000010f00000000753000000000c350000000009c400000000003e8b6000000000003e8012260d8c8ff80f03001a0000003330101060000000000000000080020050012345678901234424354455354203132333435363738616263640000000000000000000000015600015600015638333230314943434e4c2d475037333003039f37040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009f0802000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010e0000fc78fcf8f00010000000fc78fcf8f01432000013880000000000f4f0f0faaffe8000010f00000000753000000000c350000000009c400000000003e8b6000000000003e8012260d8c8ff80f03001a0000003330101030000000000000000080020050012345678901234424354455354203132333435363738616263640000000000000000000000015600015600015638333230314943434e4c2d475037333003039f37040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009f0802000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010e0000fc78fcf8f00010000000fc78fcf8f01432000013880000000000f4f0f0faaffe8000010f00000000753000000000c350000000009c400000000003e8b6000000000003e8012260d8c8ff80f03001a0000003330101020000000000000000080020050012345678901234424354455354203132333435363738616263640000000000000000000000015600015600015638333230314943434e4c2d475037333003039f37040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009f0802000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010e0000fc78fcf8f00010000000fc78fcf8f01432000013880000000000f4f0f0faaffe8000010f00000000753000000000c350000000009c400000000003e8b6000000000003e8012260d8c8ff80f03001a0000003330101010000000000000000080020050012345678901234424354455354203132333435363738616263640000000000000000000000015600015600015638333230314943434e4c2d475037333003039f37040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009f0802000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010e0000";
//    // pos.readEmvAppConfig();
//    
   // NSString *emvCapkCfg = @"a3767abd1b6aa69d7f3fbf28c092de9ed1e658ba5f0909af7a1ccd907373b7210fdeb16287ba8e78e1529f443976fd27f991ec67d95e5f4e96b127cab2396a94d6e45cda44ca4c4867570d6b07542f8d4bf9ff97975db9891515e66f525d2b3cbeb6d662bfb6c3f338e93b02142bfc44173a3764c56aadd202075b26dc2f9f7d7ae74bd7d00fd05ee430032663d27a5700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009000000303bb335a8549a03b87ab089d006f60852e4b806020211231a00000033302010100000000b0627dee87864f9c18c13b9a1f025448bf13c58380c91f4ceba9f9bcb214ff8414e9b59d6aba10f941c7331768f47b2127907d857fa39aaf8ce02045dd01619d689ee731c551159be7eb2d51a372ff56b556e5cb2fde36e23073a44ca215d6c26ca68847b388e39520e0026e62294b557d6470440ca0aefc9438c923aec9b2098d6d3a1af5e8b1de36f4b53040109d89b77cafaf70c26c601abdf59eec0fdc8a99089140cd2e817e335175b03b7aa33d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b000000387f0cd7c0e86f38f89a66f8c47071a8b88586f2620211231a00000033303010100000000bc853e6b5365e89e7ee9317c94b02d0abb0dbd91c05a224a2554aa29ed9fcb9d86eb9ccbb322a57811f86188aac7351c72bd9ef196c5a01acef7a4eb0d2ad63d9e6ac2e7836547cb1595c68bcbafd0f6728760f3a7ca7b97301b7e0220184efc4f653008d93ce098c0d93b45201096d1adff4cf1f9fc02af759da27cd6dfd6d789b099f16f378b6100334e63f3d35f3251a5ec78693731f5233519cdb380f5ab8c0f02728e91d469abd0eae0d93b1cc66ce127b29c7d77441a49d09fca5d6d9762fc74c31bb506c8bae3c79ad6c2578775b95956b5370d1d0519e37906b384736233251e8f09ad79dfbe2c6abfadac8e4d8624318c27daf1f8000003f527081cf371dd7e1fd4fa414a665036e0f5e6e520211231a00000033304010100000000b61645edfd5498fb246444037a0fa18c0f101ebd8efa54573ce6e6a7fbf63ed21d66340852b0211cf5eef6a1cd989f66af21a8eb19dbd8dbc3706d135363a0d683d046304f5a836bc1bc632821afe7a2f75da3c50ac74c545a754562204137169663cfcc0b06e67e2109eba41bc67ff20cc8ac80d7b6ee1a95465b3b2657533ea56d92d539e5064360ea4850fed2d1bf000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000090000003ee23b616c95c02652ad18860e48787c079e8e85a20301231a00000033308010100000000eb374dfc5a96b71d2863875eda2eafb96b1b439d3ece0b1826a2672eeefa7990286776f8bd989a15141a75c384dfc14fef9243aab32707659be9e4797a247c2f0b6d99372f384af62fe23bc54bcdc57a9acd1d5585c303f201ef4e8b806afb809db1a3db1cd112ac884f164a67b99c7d6e5a8a6df1d3cae6d7ed3d5be725b2de4ade23fa679bf4eb15a93d8a6e29c7ffa1a70de2e54f593d908a3bf9ebbd760bbfdc8db8b54497e6c5be0e4a4dac29e5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b0000003a075306eab0045baf72cdd33b3b678779de1f52720301231a00000033309010100000000b2ab1b6e9ac55a75adfd5bbc34490e53c4c3381f34e60e7fac21cc2b26dd34462b64a6fae2495ed1dd383b8138bea100ff9b7a111817e7b9869a9742b19e5c9dac56f8b8827f11b05a08eccf9e8d5e85b0f7cfa644eff3e9b796688f38e006deb21e101c01028903a06023ac5aab8635f8e307a53ac742bdce6a283f585f48ef00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000003c88be6b2417c4f941c9371ea35a377158767e4e320301231a0000003330a010100000000cf9fdf46b356378e9af311b0f981b21a1f22f250fb11f55c958709e3c7241918293483289eae688a094c02c344e2999f315a72841f489e24b1ba0056cfab3b479d0e826452375dcdbb67e97ec2aa66f4601d774feaef775accc621bfeb65fb0053fc5f392aa5e1d4c41a4de9ffdfdf1327c4bb874f1f63a599ee3902fe95e729fd78d4234dc7e6cf1ababaa3f6db29b7f05d1d901d2e76a606a8cbffffecbd918fa2d278bdb43b0434f5d45134be1c2781d157d501ff43e5f1c470967cd57ce53b64d82974c8275937c5d8502a1252a8a5d6088a259b694f98648d9af2cb0efd9d943c69f896d49fa39702162acb5af29b90bade005bc157f8000003bd331f9996a490b33c13441066a09ad3feb5f66c20301231a0000003330b010100000000cf9fdf46b356378e9af311b0f981b21a1f22f250fb11f55c958709e3c7241918293483289eae688a094c02c344e2999f315a72841f489e24b1ba0056cfab3b479d0e826452375dcdbb67e97ec2aa66f4601d774feaef775accc621bfeb65fb0053fc5f392aa5e1d4c41a4de9ffdfdf1327c4bb874f1f63a599ee3902fe95e729fd78d4234dc7e6cf1ababaa3f6db29b7f05d1d901d2e76a606a8cbffffecbd918fa2d278bdb43b0434f5d45134be1c2781d157d501ff43e5f1c470967cd57ce53b64d82974c8275937c5d8502a1252a8a5d6088a259b694f98648d9af2cb0efd9d943c69f896d49fa39702162acb5af29b90bade005bc157f8000003c9dbfa54a4ac5c7c947d4c8b5b08d90d0319541520301231a0000003330c010100000000";
    // pos.readEmvCapkConfig();
    //[pos updateEmvConfig:emvAppCfg emvCapk:emvCapkCfg];
    NSString *emvAppCfg = [Util byteArray2Hex:[self readLine:@"kernel_app_"]];
    NSString *emvCapkCfg = [Util byteArray2Hex:[self readLine:@"capk_"]];
    
    if (emvAppCfg != nil && ![emvAppCfg  isEqual: @""] && ![emvCapkCfg isEqualToString:@""] && emvCapkCfg != nil) {
        [pos updateEmvConfig:emvCapkCfg emvCapk:emvCapkCfg];
      
        self.textViewLog.backgroundColor = [UIColor grayColor];
        self.btnUpdateEmvCfg.enabled = NO;
        
        self.textViewLog.text = @"emv config is updating,pls wait a moment...";
    }else{
        self.textViewLog.text = @"pls make sure that you've passed the right emv config file";
    }
    
    
}

-(void)testDoTradeNFC{
    
    mTransType = TransactionType_GOODS;
    _currencyCode = @"156";
    //获取系统是24小时制或者12小时制
    NSString*formatStringForHours = [NSDateFormatter dateFormatFromTemplate:@"j" options:0 locale:[NSLocale currentLocale]];
    NSRange containsA =[formatStringForHours rangeOfString:@"a"];
    BOOL hasAMPM =containsA.location != NSNotFound;
    //hasAMPM==TURE为12小时制，否则为24小时制
    if (hasAMPM) {
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        [dateFormatter setDateFormat:@"yyyyMMddhhmmss"];
        _terminalTime = [dateFormatter stringFromDate:[NSDate date]];
        
        
    }else{
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
         _terminalTime = [dateFormatter stringFromDate:[NSDate date]];
       
    }

    
    NSMutableDictionary *dataDict = [NSMutableDictionary dictionary];
    [dataDict setObject:[NSString stringWithFormat:@"%d",30] forKey:@"timeout"];
    [dataDict setObject:[NSString stringWithFormat:@"%ld",(long)mTransType] forKey:@"transactionType"];
    [dataDict setObject:_terminalTime forKey:@"TransactionTime"];
    [dataDict setObject:[NSString stringWithFormat:@"%d",0] forKey:@"keyIndex"];
    [dataDict setObject:[NSString stringWithFormat:@"%ld",(long)CardTradeMode_SWIPE_TAP_INSERT_CARD] forKey:@"cardTradeMode"];
    [dataDict setObject:[@"0" stringByAppendingString:_currencyCode] forKey:@"currencyCode"];
    [dataDict setObject:@"000139" forKey:@"random"];
    [dataDict setObject:@"1234567890123456" forKey:@"extraData"];
    [dataDict setObject:@"" forKey:@"customDisplayString"];
    [pos doTradeAll:dataDict];
}

//开始 start 按钮事件
- (IBAction)doTrade:(id)sender {
    self.textViewLog.backgroundColor = [UIColor whiteColor];
    self.textViewLog.text = @"Starting...";
    //get system time,12hrs or 24hrs
    NSString*formatStringForHours = [NSDateFormatter dateFormatFromTemplate:@"j" options:0 locale:[NSLocale currentLocale]];
    NSRange containsA =[formatStringForHours rangeOfString:@"a"];
    BOOL hasAMPM =containsA.location != NSNotFound;
    if (hasAMPM) {
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        [dateFormatter setDateFormat:@"yyyyMMddhhmmss"];
         _terminalTime = [dateFormatter stringFromDate:[NSDate date]];
        
    }else{
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
        _terminalTime = [dateFormatter stringFromDate:[NSDate date]];
        
    }

      mTransType = TransactionType_GOODS;
      _currencyCode = @"0156";
     [pos setCardTradeMode:CardTradeMode_SWIPE_TAP_INSERT_CARD];
     [pos doTrade:30];
    
    
    
}
-(void)updateEMVAPP{
    
    NSMutableDictionary * emvAPPDict = [pos EmvAppTag];
    
    //NSString  AID = @"A0000000031010";
    //NSString * o9  =[[emvAPPDict valueForKey:@"Application_Identifier_AID_terminal"] stringByAppendingString:[self getEMVStr:@"A0000003330101"]];
    NSString * o1  =[[emvAPPDict valueForKey:@"ICS"] stringByAppendingString:[self getEMVStr:@"F4F070FAAFFE8000"]];
    NSString * o2 =[[emvAPPDict valueForKey:@"Acquirer_Identifier"] stringByAppendingString:[self getEMVStr:@"000000008080"]];
    NSString * o3 =[[emvAPPDict valueForKey:@"Merchant_Category_Code"] stringByAppendingString:[self getEMVStr:@"1234"]];
    NSString * o4  =[[emvAPPDict valueForKey:@"Merchant_Identifier"] stringByAppendingString:[self getEMVStr:[self getHexFromStr: @"BCTEST 12345678"]]];
    //test
    NSString * o5  = [[emvAPPDict valueForKey:@"Transaction_Currency_Code"] stringByAppendingString:[self getEMVStr:@"0840"]];
    NSString * o6  = [[emvAPPDict valueForKey:@"Terminal_Country_Code"] stringByAppendingString:[self getEMVStr:@"0840"]];
    NSString * o7  =[[emvAPPDict valueForKey:@"terminal_contactless_transaction_limit"] stringByAppendingString:[self getEMVStr:@"000000001000"]];
    NSString * o8  =[[emvAPPDict valueForKey:@"terminal_execute_cvm_limit"] stringByAppendingString:[self getEMVStr:@"000000001000"]];
    NSArray *certainAIDConfigArr = @[o1,o3,o4,o5,o6,o7,o8];
    [pos updateEmvAPP:EMVOperation_update data:certainAIDConfigArr block:^(BOOL isSuccess, NSString *stateStr) {
        if (isSuccess) {
            self.textViewLog.text = stateStr;
            
        }else{
            self.textViewLog.text = [NSString stringWithFormat:@"update aid fail"];
        }
    }];
}
- (IBAction)getPosInfo:(id)sender {
    self.textViewLog.backgroundColor = [UIColor yellowColor];
    self.textViewLog.text = @"starting...";
 
   [pos getQPosInfo];
//    [self getTotalCount];
   
}

-(void)connectPrinterNoScan{
     [pos connectBluetoothNoScan:@"S85"];
}
-(void)printText{
    [[Print sharedInstance]  setAsciiWordFormat:0 bold:NO doubleHeight:NO doubleWidth:NO underline:NO];
    NSString *sData = [[NSUserDefaults standardUserDefaults]objectForKey:@"swipeData"];
    NSString *iData = [[NSUserDefaults standardUserDefaults]objectForKey:@"iccData"];
    [[Print sharedInstance]  printTxt:[NSString stringWithFormat:@"%@\n",sData]];
    [[Print sharedInstance]  printTxt:[NSString stringWithFormat:@"%@\n",iData]];
}

- (IBAction)resetpos:(id)sender {
    
    [pos asynResetPosStatusBlock:^(BOOL isSuccess, NSString *stateStr) {
        if (isSuccess) {
            self.textViewLog.text = stateStr;
        }
    }];
}


- (IBAction)getInputAmount:(id)sender {
    self.textViewLog.backgroundColor = [UIColor whiteColor];
    
    [pos getInputAmountWithSymbolAmountMaxLen:4 customerDisplay:@"geopago" delay:30 block:^(BOOL isSuccess, NSString *amountStr) {
        if (isSuccess) {
            self.textViewLog.text = amountStr;
        }
    }];
    //    [pos resetPosStatus];
    
        NSString *a = [Util byteArray2Hex:[Util stringFormatTAscii:@"622526XXXXXX5453"] ];
        [pos getPin:1 keyIndex:0 maxLen:6 typeFace:@"Pls Input Pin" cardNo:a data:@"" delay:30 withResultBlock:^(BOOL isSuccess, NSDictionary *result) {
            NSLog(@"result: %@",result);
        }];
    
    

    
    
}

- (IBAction)buildPinBlock:(id)sender {
    
     NSString *a = [Util byteArray2Hex:[Util stringFormatTAscii:@"622526XXXXXX5453"] ];
//    [pos getPin:1 keyIndex:0 maxLen:6 typeFace:@"pls input pin" cardNo:a data:@"20170810" delay:30 withResultBlock:^(BOOL isSuccess, NSDictionary *result) {
//        
//        if (isSuccess) {
//            NSString *aStr = @"encryptMode: ";
//            aStr = [aStr stringByAppendingString:result[@"encryptMode"]];
//            aStr = [aStr stringByAppendingString:@"\n"];
//            aStr = [aStr stringByAppendingString:@"ksn:"];
//            aStr = [aStr stringByAppendingString:result[@"ksn"]];
//            aStr = [aStr stringByAppendingString:@"\n"];
//            aStr = [aStr stringByAppendingString:@"pinBlock:"];
//            aStr = [aStr stringByAppendingString:result[@"pin"]];
//            
//            self.textViewLog.text = aStr;
//        }
//        
    //}];
//     [pos buildPinBlock:@"558A532236CB58B30C130D8F8D75C22A" workKeyCheck:@"00F52F1E33BA1002" encryptType:1 keyIndex:0 maxLen:6 typeFace:@"pls input pin" cardNo:a date:@"20170810" delay:30];
    
}
- (IBAction)isCardExist:(id)sender {
    self.textViewLog.backgroundColor = [UIColor whiteColor];
    self.textViewLog.text = @"Starting...";
    
    [pos isCardExist:5 withResultBlock:^(BOOL res) {
        if (res) {
            NSLog(@"isCardExist %d",res);
            self.textViewLog.text = @"1";
            
        }else{
            self.textViewLog.text = @"0";
        }
        
    }];
}


- (NSData*)readLine:(NSString*)name
{
    NSString* file = [[NSBundle mainBundle]pathForResource:name ofType:@".asc"];
    NSFileManager* Manager = [NSFileManager defaultManager];
    NSData* data = [[NSData alloc] init];
    data = [Manager contentsAtPath:file];
    return data;
}


-(void)testUpdatePosFirmware{
    NSData *data = [self readLine:@"upgrader"];//read a14upgrader.asc
    
    if (data != nil) {
        [[QPOSService sharedInstance] updatePosFirmware:data address:self.bluetoothAddress];
    }else{
        self.textViewLog.text = @"pls make sure you have passed the right data";
        
    }
    
   
}

-(void) onUpdatePosFirmwareResult:(UpdateInformationResult)updateInformationResult{
    NSLog(@"%ld",(long)updateInformationResult);
   
    if (updateInformationResult==UpdateInformationResult_UPDATE_SUCCESS) {
        self.textViewLog.text = @"Success";
    }else if(updateInformationResult==UpdateInformationResult_UPDATE_FAIL){
        self.textViewLog.text =  @"Failed";
    }else if(updateInformationResult==UpdateInformationResult_UPDATE_PACKET_LEN_ERROR){
        self.textViewLog.text =  @"Packet len error";
    }
    else if(updateInformationResult==UpdateInformationResult_UPDATE_PACKET_VEFIRY_ERROR){
        self.textViewLog.text =  @"Packer vefiry error";
    }else{
        self.textViewLog.text = @"firmware updating...";
    }

}

-(void)calcMacDouble:(NSString *)cal{
    NSData *aa =  [Util ecb:[Util HexStringToByteArray:cal]];
    NSLog(@"aa = %@",aa);
    [pos calcMacDouble_all:[Util byteArray2Hex:aa] keyIndex:0 delay:10];
}

-(void)calcMacSingle:(NSString *)cal{
    NSData *aa =  [Util ecb:[Util HexStringToByteArray:cal]];
    NSLog(@"aa = %@",aa);
    [pos calcMacSingle_all:[Util byteArray2Hex:aa] delay:10];
}

#pragma mark - Managing the detail item

- (void)setDetailItem:(id)newDetailItem
{
    if (_detailItem != newDetailItem) {
        _detailItem = newDetailItem;
        
        // Update the view.
        [self configureView];
    }
}

- (void)configureView
{
    // Update the user interface for the detail item.
    if (self.detailItem) {
        NSString *aStr = [self.detailItem description];
        self.bluetoothAddress = aStr;
        /*if (pos==nil) {
         pos = [[QPOSService new] initWithBlueTooth:nil BlueToothAddr:self.bluetoothAddress PosEventListener:self];
         }
         */
        //self.detailDescriptionLabel.text = aStr;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self configureView];
    self.btnDisconnect.layer.cornerRadius = 10;
    self.btnStart.layer.cornerRadius = 10;
    self.btnGetPosId.layer.cornerRadius = 10;
    self.btnGetPosInfo.layer.cornerRadius = 10;
    self.btnResetPos.layer.cornerRadius = 10;
    self.btnIsCardExist.layer.cornerRadius = 10;
    if (nil == pos) {
        pos = [QPOSService sharedInstance];
    }
    
    [pos setDelegate:self];
    self.labSDK.text =[@"V" stringByAppendingString:[pos getSdkVersion]];
    
    //    self_queue = dispatch_queue_create("demo.queue", NULL);
    //    [pos setQueue:self_queue];
    
    [pos setQueue:nil];
    doTradeByEnterAmount = true;
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
        //        mPosType = PosType_BLUETOOTH;
        //        [pos setPosType:PosType_BLUETOOTH];
        
        //        mPosType = PosType_BLUETOOTH_new;
        //        [pos setPosType:PosType_BLUETOOTH_new];
        
        mPosType = PosType_BLUETOOTH_2mode;
        [pos setPosType:PosType_BLUETOOTH_2mode];
        
        self.textViewLog.text = @"connecting bluetooth...";
        [pos connectBT:self.bluetoothAddress];
        [pos setBTAutoDetecting:true];
    }
    
    
}

- (IBAction)powerOnIcc:(id)sender {
    
    [pos powerOnIcc];
    //__weak typeof(self) weakSelf = self;
    /*[pos sendApdu:@"00A404000CA00000024300130000000101" block:^(BOOL isSuccess, NSData *result) {
        if (isSuccess) {
            weakSelf.textViewLog.text = [Util byteArray2Hex:result];
            weakSelf.apduStr = result;
        }
        
     }];*/
    self.textViewLog.text = @"send apdu...";
    NSData *apduData = [pos sycnSendApdu:@"00A404000CA00000024300130000000101"];
    NSLog(@"%@",apduData);
    NSData *apduData2 = [pos sycnSendApdu:@"00A404000CA00000024300130000000102"];
 
    
    
   
    
}

// 十六进制转换为普通字符串
+ (NSString *)stringFromHexString:(NSString *)hexString { //
    
    char *myBuffer = (char *)malloc((int)[hexString length] / 2 + 1);
    bzero(myBuffer, [hexString length] / 2 + 1);
    for (int i = 0; i < [hexString length] - 1; i += 2) {
        unsigned int anInt;
        NSString * hexCharStr = [hexString substringWithRange:NSMakeRange(i, 2)];
        NSScanner * scanner = [[NSScanner alloc] initWithString:hexCharStr];
        [scanner scanHexInt:&anInt];
        myBuffer[i / 2] = (char)anInt;
    }
    NSString *unicodeString = [NSString stringWithCString:myBuffer encoding:4];
    NSLog(@"------字符串=======%@",unicodeString);
    return unicodeString; 
    
    
}

-(void) sleepMs: (NSInteger)msec {
    NSTimeInterval sec = (msec / 1000.0f);
    [NSThread sleepForTimeInterval:sec];
}
- (IBAction)setQuickEmv:(id)sender {
     __weak typeof(self)weakself = self;
//    [pos setIsQuickEMV:false block:^(BOOL isSuccess, NSString *stateStr) {
//        if (isSuccess) {
//            weakself.textViewLog.text = stateStr;
//        }
//    }];
    
    
}

- (IBAction)updateA27CAYC:(id)sender {
    [self testUpdatePosFirmware];
    self.textViewLog.text = @"firmware updating...";
}

- (IBAction)updateA19K:(id)sender {
    NSData *data = [self readLine:@"A19K"];//read a14upgrader.asc
    [[QPOSService sharedInstance] updatePosFirmware:data address:self.bluetoothAddress];
    self.textViewLog.text = @"firmware updating...";
}



- (IBAction)getTradeLog:(id)sender {
        __weak typeof(self)weakself = self;
        
        [pos doTradeLogOperation:2 data:0 block:^(BOOL isSuccess,NSInteger markType, NSDictionary *stateStr) {
            if (isSuccess) {
                if (markType == 0) {
                    NSLog(@"decodeData: %@",stateStr);
                    NSString *formatID = [NSString stringWithFormat:@"Format ID: %@\n",stateStr[@"formatID"]] ;
                    NSString *maskedPAN = [NSString stringWithFormat:@"Masked PAN: %@\n",stateStr[@"maskedPAN"]];
                    NSString *expiryDate = [NSString stringWithFormat:@"Expiry Date: %@\n",stateStr[@"expiryDate"]];
                    NSString *cardHolderName = [NSString stringWithFormat:@"Cardholder Name: %@\n",stateStr[@"cardholderName"]];
                    //NSString *ksn = [NSString stringWithFormat:@"KSN: %@\n",decodeData[@"ksn"]];
                    NSString *serviceCode = [NSString stringWithFormat:@"Service Code: %@\n",stateStr[@"serviceCode"]];
                    //NSString *track1Length = [NSString stringWithFormat:@"Track 1 Length: %@\n",decodeData[@"track1Length"]];
                    //NSString *track2Length = [NSString stringWithFormat:@"Track 2 Length: %@\n",decodeData[@"track2Length"]];
                    //NSString *track3Length = [NSString stringWithFormat:@"Track 3 Length: %@\n",decodeData[@"track3Length"]];
                    //NSString *encTracks = [NSString stringWithFormat:@"Encrypted Tracks: %@\n",decodeData[@"encTracks"]];
                    NSString *encTrack1 = [NSString stringWithFormat:@"Encrypted Track 1: %@\n",stateStr[@"encTrack1"]];
                    NSString *encTrack2 = [NSString stringWithFormat:@"Encrypted Track 2: %@\n",stateStr[@"encTrack2"]];
                    NSString *encTrack3 = [NSString stringWithFormat:@"Encrypted Track 3: %@\n",stateStr[@"encTrack3"]];
                    //NSString *partialTrack = [NSString stringWithFormat:@"Partial Track: %@",decodeData[@"partialTrack"]];
                    NSString *pinKsn = [NSString stringWithFormat:@"PIN KSN: %@\n",stateStr[@"pinKsn"]];
                    NSString *trackksn = [NSString stringWithFormat:@"Track KSN: %@\n",stateStr[@"trackksn"]];
                    NSString *pinBlock = [NSString stringWithFormat:@"pinBlock: %@\n",stateStr[@"pinblock"]];
                    NSString *encPAN = [NSString stringWithFormat:@"encPAN: %@\n",stateStr[@"encPAN"]];
                    
                    NSString *msg = [NSString stringWithFormat:@"Card Swiped:\n"];
                    msg = [msg stringByAppendingString:formatID];
                    msg = [msg stringByAppendingString:maskedPAN];
                    msg = [msg stringByAppendingString:expiryDate];
                    msg = [msg stringByAppendingString:cardHolderName];
                    //msg = [msg stringByAppendingString:ksn];
                    msg = [msg stringByAppendingString:pinKsn];
                    msg = [msg stringByAppendingString:trackksn];
                    msg = [msg stringByAppendingString:serviceCode];
                    
                    msg = [msg stringByAppendingString:encTrack1];
                    msg = [msg stringByAppendingString:encTrack2];
                    msg = [msg stringByAppendingString:encTrack3];
                    msg = [msg stringByAppendingString:pinBlock];
                    msg = [msg stringByAppendingString:encPAN];
                    NSLog(@"******%@",msg);
                    weakself.textViewLog.text = msg;
                    weakself.textViewLog.backgroundColor = [UIColor greenColor];
                }else if(markType == 03) {
                    NSLog(@"decodeData: %@",stateStr);
                    NSString *formatID = [NSString stringWithFormat:@"Format ID: %@\n",stateStr[@"formatID"]] ;
                    NSString *maskedPAN = [NSString stringWithFormat:@"Masked PAN: %@\n",stateStr[@"maskedPAN"]];
                    NSString *expiryDate = [NSString stringWithFormat:@"Expiry Date: %@\n",stateStr[@"expiryDate"]];
                    NSString *cardHolderName = [NSString stringWithFormat:@"Cardholder Name: %@\n",stateStr[@"cardholderName"]];
                    //NSString *ksn = [NSString stringWithFormat:@"KSN: %@\n",decodeData[@"ksn"]];
                    NSString *serviceCode = [NSString stringWithFormat:@"Service Code: %@\n",stateStr[@"serviceCode"]];
                    //NSString *track1Length = [NSString stringWithFormat:@"Track 1 Length: %@\n",decodeData[@"track1Length"]];
                    //NSString *track2Length = [NSString stringWithFormat:@"Track 2 Length: %@\n",decodeData[@"track2Length"]];
                    //NSString *track3Length = [NSString stringWithFormat:@"Track 3 Length: %@\n",decodeData[@"track3Length"]];
                    //NSString *encTracks = [NSString stringWithFormat:@"Encrypted Tracks: %@\n",decodeData[@"encTracks"]];
                    NSString *encTrack1 = [NSString stringWithFormat:@"Encrypted Track 1: %@\n",stateStr[@"encTrack1"]];
                    NSString *encTrack2 = [NSString stringWithFormat:@"Encrypted Track 2: %@\n",stateStr[@"encTrack2"]];
                    NSString *encTrack3 = [NSString stringWithFormat:@"Encrypted Track 3: %@\n",stateStr[@"encTrack3"]];
                    //NSString *partialTrack = [NSString stringWithFormat:@"Partial Track: %@",decodeData[@"partialTrack"]];
                    NSString *pinKsn = [NSString stringWithFormat:@"PIN KSN: %@\n",stateStr[@"pinKsn"]];
                    NSString *trackksn = [NSString stringWithFormat:@"Track KSN: %@\n",stateStr[@"trackksn"]];
                    NSString *pinBlock = [NSString stringWithFormat:@"pinBlock: %@\n",stateStr[@"pinblock"]];
                    NSString *encPAN = [NSString stringWithFormat:@"encPAN: %@\n",stateStr[@"encPAN"]];
                    
                    NSString *msg = [NSString stringWithFormat:@"Tap Card:\n"];
                    msg = [msg stringByAppendingString:formatID];
                    msg = [msg stringByAppendingString:maskedPAN];
                    msg = [msg stringByAppendingString:expiryDate];
                    msg = [msg stringByAppendingString:cardHolderName];
                    //msg = [msg stringByAppendingString:ksn];
                    msg = [msg stringByAppendingString:pinKsn];
                    msg = [msg stringByAppendingString:trackksn];
                    msg = [msg stringByAppendingString:serviceCode];
                    
                    msg = [msg stringByAppendingString:encTrack1];
                    msg = [msg stringByAppendingString:encTrack2];
                    msg = [msg stringByAppendingString:encTrack3];
                    msg = [msg stringByAppendingString:pinBlock];
                    msg = [msg stringByAppendingString:encPAN];
                    weakself.textViewLog.text = msg;
                    weakself.textViewLog.backgroundColor = [UIColor greenColor];
                }else{
                    
                    
                    NSString * data = [stateStr valueForKey:@"log"];
                    weakself.textViewLog.text = data;
                    weakself.textViewLog.backgroundColor = [UIColor greenColor];
                    
                }
                
            }
        }];
    
    //NSDictionary * doTradeLogDictionary = [pos syncDoTradeLogOperation:0 data:0];
    //[pos doTrade:30];
    //  NSLog(@"doTradeLogDictionary = %@",doTradeLogDictionary);
   
};

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(void)viewDidDisappear:(BOOL)animated{
    
    if (mPosType == PosType_AUDIO) {
        NSLog(@"viewDidDisappear stop audio");
        //        [pos resetPosStatus];
        [pos stopAudio];
    }else if(mPosType == PosType_BLUETOOTH || mPosType == PosType_BLUETOOTH_new || mPosType == PosType_BLUETOOTH_2mode){
        NSLog(@"viewDidDisappear disconnect buluetooth");
        [pos disconnectBT];
    }
    
}

typedef NS_ENUM(NSInteger, MSG_PRO) {
    MSG_DOTRADE,
};

-(void)appMsg:(MSG_PRO)index{
    switch (index) {
        case MSG_DOTRADE:
        {
            
            dispatch_async(dispatch_get_main_queue(),  ^{
                [pos doTrade:30];
            });
        }
            break;
            
        default:
            break;
    }
}
- (IBAction)sendAPDU:(id)sender {
    self.textViewLog.text = @"send apdu...";
    [pos sendApdu:@"00A404000AA0000000744A504E0010"];
}

- (IBAction)powerOffIcc:(id)sender {
    self.textViewLog.text = @"power off icc..";
    [pos powerOffIcc];
}

- (IBAction)updatePosFirmware:(id)sender {
    [self testUpdatePosFirmware];
    self.textViewLog.text = @"firmware updating...";
    [self updateProgress];
    appearTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(progressMethod) userInfo:nil repeats:YES];
}

-(void)updateProgress{
    //初始化
    progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    progressView.frame = (CGRect){150,110,160,50};
    progressView.trackTintColor = [UIColor blackColor];
    progressView.progress = 0.0;
    progressView.progressTintColor = [UIColor greenColor];
    progressView.progressImage = [UIImage imageNamed:@""];
    [self.view addSubview:progressView];
    
}

-(NSInteger)getProgress{
    return [pos getUpdateProgress];
}
-(void)progressMethod{
    dispatch_async(dispatch_get_main_queue(),  ^{
        self_queue = dispatch_queue_create("updateProgress",DISPATCH_QUEUE_CONCURRENT);
        dispatch_sync(self_queue, ^{
            NSInteger updateProgress =  [self getProgress];
            NSString *str = [NSString stringWithFormat:@"%ld",(long)updateProgress];
            float floatString = [str floatValue]/100;
            if(floatString >0&& floatString< 1 ) {
                [progressView setProgress:floatString animated:YES];
                self.updateProgressLab.text = [NSString stringWithFormat:@"progress: %.0f %s",floatString*100,"%"];
            }if (floatString == 1.0) {
                [progressView setTrackTintColor:[UIColor greenColor]];
                [progressView setProgressTintColor:[UIColor greenColor]];
                self.updateProgressLab.text = @"100%";
            }
            
        });
        
    });
    
}
-(void)addEMVAPP{
    NSMutableDictionary * emvAPPDict = [pos getEMVAPPDict];
#pragma mark aid2
    NSString *AID = @"A0000000044010";
    NSString * o1  =[[emvAPPDict valueForKey:@"Application_Identifier_AID_terminal"] stringByAppendingString:[self getEMVStr:AID]];
    NSString * o2 =[[emvAPPDict valueForKey:@"TAC_Default"] stringByAppendingString:[self getEMVStr:@"FC5080A000"]];
    NSString * o3  =[[emvAPPDict valueForKey:@"TAC_Online"] stringByAppendingString:[self getEMVStr:@"FC5080F800"]];
    NSString * o4  =[[emvAPPDict valueForKey:@"TAC_Denial"] stringByAppendingString:[self getEMVStr:@"0000000000"]];
    NSString * o5 =[[emvAPPDict valueForKey:@"Target_Percentage_to_be_Used_for_Random_Selection"] stringByAppendingString:[self getEMVStr:@"00"]];
    NSString * o6  =[[emvAPPDict valueForKey:@"Maximum_Target_Percentage_to_be_used_for_Biased_Random_Selection"] stringByAppendingString:[self getEMVStr:@"00"]];
    NSString * o7  =[[emvAPPDict valueForKey:@"Threshold_Value_BiasedRandom_Selection"] stringByAppendingString:[self getEMVStr:[self getHexFromIntStr:@"999999"]]];
    NSString * o8  =[[emvAPPDict valueForKey:@"Terminal_Floor_Limit"] stringByAppendingString:[self getEMVStr:@"00000000"]];
    NSString * o9 =[[emvAPPDict valueForKey:@"Application_Version_Number"] stringByAppendingString:[self getEMVStr:@"0002"]];
    NSString * o10 =[[emvAPPDict valueForKey:@"Point_of_Service_POS_EntryMode"] stringByAppendingString:[self getEMVStr:@"05"]];
    NSString * o11  =[[emvAPPDict valueForKey:@"Acquirer_Identifier"] stringByAppendingString:[self getEMVStr:@"000000008080"]];
    NSString * o12 =[[emvAPPDict valueForKey:@"Merchant_Category_Code"] stringByAppendingString:[self getEMVStr:@"1234"]];
    NSString * o13  =[[emvAPPDict valueForKey:@"Merchant_Identifier"] stringByAppendingString:[self getEMVStr:[self getHexFromStr: @"BCTEST 12345678"]]];
    NSString * o14  =[[emvAPPDict valueForKey:@"Merchant_Name_and_Location"] stringByAppendingString:[self getEMVStr:[[self getHexFromStr:@"abcd"] stringByAppendingString:@"0000000000000000000000"]]];
    NSString * o15  = [[emvAPPDict valueForKey:@"Transaction_Currency_Code"] stringByAppendingString:[self getEMVStr:@"0608"]];
    NSString * o16 = [[emvAPPDict valueForKey:@"Transaction_Currency_Exponent"] stringByAppendingString:[self getEMVStr:@"02"]];
    NSString * o17  = [[emvAPPDict valueForKey:@"Transaction_Reference_Currency_Code"] stringByAppendingString:[self getEMVStr:@"0608"]];
    NSString * o18 = [[emvAPPDict valueForKey:@"Transaction_Reference_Currency_Exponent"] stringByAppendingString:[self getEMVStr:@"02"]];
    NSString * o19  = [[emvAPPDict valueForKey:@"Terminal_Country_Code"] stringByAppendingString:[self getEMVStr:@"0608"]];
    NSString * o20  = [[emvAPPDict valueForKey:@"Interface_Device_IFD_Serial_Number"] stringByAppendingString:[self getEMVStr:[self getHexFromStr:@"83201ICC"]]];
    NSString * o21 =[[emvAPPDict valueForKey:@"Terminal_Identification"] stringByAppendingString:[self getEMVStr:[self getHexFromStr:@"NL-GP730"]]];
    NSString * o22  =[[emvAPPDict valueForKey:@"Default_DDOL"] stringByAppendingString:[self getEMVStr:@"9f3704"]];
    NSString * o23 =[[emvAPPDict valueForKey:@"Default_Tdol"] stringByAppendingString:[self getEMVStr:@"9F1A0295059A039C01"]];
    NSString * o24  =[[emvAPPDict valueForKey:@"Application_Selection_Indicator"] stringByAppendingString:[self getEMVStr:@"01"]];
    
    NSArray *certainAIDConfigArr = @[o1,o2,o3,o4,o5,o6,o7,o8,o9,o10,o11,o12,o13,o14,o15,o16,o17,o18,o19,o20,o21,o22,o23,o24];
    [pos updateEmvAPP:EMVOperation_add data:certainAIDConfigArr block:^(BOOL isSuccess, NSString *stateStr) {
        if (isSuccess) {
            self.textViewLog.text = stateStr;
            
        }else{
            self.textViewLog.text = [NSString stringWithFormat:@"update aid fail"];
        }
    }];
}
-(void)deleteEMVAPP{
    NSArray *certainAIDConfigArr = @[@"A0000000044010"];
    [pos updateEmvAPP:EMVOperation_delete data:certainAIDConfigArr block:^(BOOL isSuccess, NSString *stateStr) {
        if (isSuccess) {
            self.textViewLog.text = stateStr;
            
        }else{
            self.textViewLog.text = [NSString stringWithFormat:@"update aid fail"];
        }
    }];
}

-(NSString* )getEMVStr:(NSString *)emvStr{
    NSInteger emvLen = 0;
    if (emvStr != NULL &&![emvStr  isEqual: @""]) {
        if ([emvStr length]%2 != 0) {
            emvStr = [@"0" stringByAppendingString:emvStr];
        }
        emvLen = [emvStr length]/2;
    }else{
        NSLog(@"init emv app config str could not be empty");
        return nil;
    }
    NSData *emvLenData = [Util IntToHex:emvLen];
    NSString *totalStr = [[[Util byteArray2Hex:emvLenData] substringFromIndex:2] stringByAppendingString:emvStr];
    return totalStr;
}

-(NSString *)getHexFromStr:(NSString *)str{
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    NSString *hex = [Util byteArray2Hex:data];
    return hex ;
}
- (NSString *)getHexFromIntStr:(NSString *)tmpidStr
{
    NSInteger tmpid = [tmpidStr intValue];
    NSString *nLetterValue;
    NSString *str =@"";
    int ttmpig;
    for (int i = 0; i<9; i++) {
        ttmpig=tmpid%16;
        tmpid=tmpid/16;
        switch (ttmpig)
        {
            case 10:
                nLetterValue =@"A";break;
            case 11:
                nLetterValue =@"B";break;
            case 12:
                nLetterValue =@"C";break;
            case 13:
                nLetterValue =@"D";break;
            case 14:
                nLetterValue =@"E";break;
            case 15:
                nLetterValue =@"F";break;
            default:
                nLetterValue = [NSString stringWithFormat:@"%u",ttmpig];
        }
        str = [nLetterValue stringByAppendingString:str];
        if (tmpid == 0) {
            break;
        }
    }
    //不够一个字节凑0
    if(str.length == 1){
        return [NSString stringWithFormat:@"0%@",str];
    }else{
        if ([str length]<8) {
            if ([str length] == (8-1)) {
                str = [@"0" stringByAppendingString:str];
            }else if ([str length] == (8-2)){
                str = [@"00" stringByAppendingString:str];
            }else if  ([str length] == (8-3)){
                str = [@"000" stringByAppendingString:str];
            }
            else if ([str length] == (8-4)) {
                str = [@"0000" stringByAppendingString:str];
            } else if([str length] == (8-5)){
                str = [@"00000" stringByAppendingString:str];
            }else if([str length] == (8-6)){
                str = [@"000000" stringByAppendingString:str];
            }
        }
        return str;
    }
}

-(void)updateTerminalContactlessFloorLimit{
    
    NSMutableDictionary * emvAPPDict = [pos EmvAppTag];
    NSString * contactlessLimit =[[emvAPPDict valueForKey:@"Terminal_Capabilities"] stringByAppendingString:[self getEMVStr:@"E0F8C8"]];
//    NSString * cvmlimit  =[[emvAPPDict valueForKey:@"terminal_execute_cvm_limit"] stringByAppendingString:[self getEMVStr:@"000000999999"]];
    
    NSArray *certainAIDConfigArr = @[contactlessLimit];
    [pos updateEmvAPP:EMVOperation_update data:certainAIDConfigArr block:^(BOOL isSuccess, NSString *stateStr) {
        if (isSuccess) {
            self.textViewLog.text = stateStr;
            
        }else{
            self.textViewLog.text = [NSString stringWithFormat:@"update aid fail"];
        }
    }];
}
-(void)doTradeWithBatchID{
    self.textViewLog.backgroundColor = [UIColor whiteColor];
    self.textViewLog.text = @"Starting...";
    //get system time,12hrs or 24hrs
    NSString*formatStringForHours = [NSDateFormatter dateFormatFromTemplate:@"j" options:0 locale:[NSLocale currentLocale]];
    NSRange containsA =[formatStringForHours rangeOfString:@"a"];
    BOOL hasAMPM =containsA.location != NSNotFound;
    if (hasAMPM) {
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        [dateFormatter setDateFormat:@"yyyyMMddhhmmss"];
        _terminalTime = [dateFormatter stringFromDate:[NSDate date]];
        
    }else{
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
        _terminalTime = [dateFormatter stringFromDate:[NSDate date]];
        
    }
    
    mTransType = TransactionType_GOODS;
    _currencyCode = @"0156";
    //[pos setCardTradeMode:CardTradeMode_SWIPE_INSERT_CARD];
    __weak typeof(self) weakSelf = self;
    [pos setIsQuickEMV:YES block:^(BOOL isSuccess, NSString *stateStr) {
        if (isSuccess) {
            weakSelf.textViewLog.text = stateStr;
        }
    }];
    [pos doTrade:30 batchID:@""];
}
-(void)getTotalCount{
    NSDictionary * aDict = [pos syncDoTradeLogOperation:DoTradeLog_getAllCount data:0];
    NSLog(@"adict = %@",aDict);
}
-(void)deleteOneTrade{
    NSDictionary * aDict = [pos syncDoTradeLogOperation:DoTradeLog_ClearOneByBatchID batchID:@""];
    NSLog(@"adict = %@",aDict);
}
-(void)getOneTrade{
    NSDictionary * aDict = [pos syncDoTradeLogOperation:DoTradeLog_GetOneByBatchID batchID:@""];
    NSLog(@"adict = %@",aDict);
}
@end

