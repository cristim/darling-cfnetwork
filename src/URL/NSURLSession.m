//
//  NSURLSession.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSURLSession.h>
#import <Foundation/NSURLConnection.h>
#import <Foundation/NSMutableData.h>
#import <Foundation/NSError.h>
#import <Foundation/NSURLError.h>
#import <Foundation/NSRunLoop.h>
#import <objc/runtime.h>

const int64_t NSURLSessionTransferSizeUnknown = -1LL;
NSString* const NSURLSessionDownloadTaskResumeData = @"NSURLSessionDownloadTaskResumeData";

@implementation NSURLSession

+ (void)initialize
{
    static dispatch_once_t once = 0L;
    dispatch_once(&once, ^{
        Class cls = objc_lookUpClass("__NSCFURLSession");
        assert(cls != Nil);
        class_setSuperclass(self, cls);
    });
}

@end

@interface NSURLSessionTask () {
@protected
    NSURLRequest *_originalRequest;
    NSURLRequest *_currentRequest;
    NSURLResponse *_response;
    NSError *_error;
    NSString *_taskDescription;
    NSURLSessionTaskState _state;
    NSUInteger _taskIdentifier;
    int64_t _countOfBytesReceived;
}
@end

@implementation NSURLSessionTask

- (instancetype)init
{
    if ((self = [super init])) {
        static NSUInteger nextIdentifier = 0;
        @synchronized ([NSURLSessionTask class]) {
            _taskIdentifier = ++nextIdentifier;
        }
        _state = NSURLSessionTaskStateSuspended;
    }
    return self;
}

- (NSUInteger)taskIdentifier { return _taskIdentifier; }
- (NSURLRequest *)originalRequest { return _originalRequest; }
- (NSURLRequest *)currentRequest { return _currentRequest; }
- (NSURLResponse *)response { return _response; }
- (NSError *)error { return _error; }
- (NSURLSessionTaskState)state { return _state; }
- (int64_t)countOfBytesReceived { return _countOfBytesReceived; }
- (int64_t)countOfBytesSent { return 0; }
- (int64_t)countOfBytesExpectedToSend { return NSURLSessionTransferSizeUnknown; }
- (int64_t)countOfBytesExpectedToReceive { return NSURLSessionTransferSizeUnknown; }
- (NSString *)taskDescription { return _taskDescription; }
- (void)setTaskDescription:(NSString *)description
{
    if (_taskDescription != description) {
        [_taskDescription release];
        _taskDescription = [description copy];
    }
}

- (id)copyWithZone:(NSZone *)zone { return [self retain]; }

- (void)dealloc
{
    [_originalRequest release];
    [_currentRequest release];
    [_response release];
    [_error release];
    [_taskDescription release];
    [super dealloc];
}
@end

@interface NSURLSessionDataTask () <NSURLConnectionDataDelegate> {
    NSURLConnection *_connection;
    NSMutableData *_receivedData;
    void (^_completionHandler)(NSData *, NSURLResponse *, NSError *);
}
@end

@implementation NSURLSessionDataTask

- (instancetype)initWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler
{
    if ((self = [super init])) {
        _originalRequest = [request copy];
        _currentRequest = [request copy];
        _receivedData = [[NSMutableData alloc] init];
        _completionHandler = [completionHandler copy];
    }
    return self;
}

- (void)resume
{
    @synchronized (self) {
        if (_state != NSURLSessionTaskStateSuspended)
            return;
        _state = NSURLSessionTaskStateRunning;
        _connection = [[NSURLConnection alloc] initWithRequest:_currentRequest delegate:self startImmediately:NO];
        [_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [_connection start];
    }
}

- (void)suspend
{
    // NSURLConnection cannot pause an active transfer. A newly created task
    // remains suspended until resume is called for the first time.
}

- (void)_completeWithError:(NSError *)error
{
    [self retain];
    void (^completion)(NSData *, NSURLResponse *, NSError *) = nil;
    NSData *data = nil;
    NSURLResponse *response = nil;
    @synchronized (self) {
        if (_state == NSURLSessionTaskStateCompleted) {
            [self release];
            return;
        }
        _state = NSURLSessionTaskStateCompleted;
        _error = [error retain];
        completion = [_completionHandler copy];
        data = error ? nil : [[_receivedData copy] autorelease];
        response = [[_response retain] autorelease];
        [_connection release];
        _connection = nil;
    }
    if (completion != nil) {
        completion(data, response, error);
        [completion release];
    }
    [self release];
}

- (void)cancel
{
    @synchronized (self) {
        if (_state == NSURLSessionTaskStateCompleted)
            return;
        [_connection cancel];
    }
    [self _completeWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    @synchronized (self) {
        if (_state != NSURLSessionTaskStateRunning)
            return;
        [_response release];
        _response = [response retain];
        [_receivedData setLength:0];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    @synchronized (self) {
        if (_state != NSURLSessionTaskStateRunning)
            return;
        [_receivedData appendData:data];
        _countOfBytesReceived += [data length];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self _completeWithError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self _completeWithError:nil];
}

- (void)dealloc
{
    [_connection cancel];
    [_connection release];
    [_receivedData release];
    [_completionHandler release];
    [super dealloc];
}
@end

@implementation NSURLSessionDownloadTask
@end

@implementation NSURLSessionUploadTask
@end

@implementation NSURLSessionConfiguration

static NSURLSessionConfiguration *_defaultSessionConfiguration = nil;

+ (NSURLSessionConfiguration *)defaultSessionConfiguration {
	if (_defaultSessionConfiguration == nil) {
		_defaultSessionConfiguration = [[NSURLSessionConfiguration alloc] init];
	}

	return _defaultSessionConfiguration;
}

@end
