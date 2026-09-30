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

@implementation NSURLSessionTask

- (id)initWithRequest: (NSURLRequest *) request completionHandler: (void (^)(NSData *, NSURLResponse *, NSError *)) completionHandler
{
    self = [super init];
    if (self)
    {
        static NSUInteger lastIdentifier = 0;

        _originalRequest = [request copy];
        _currentRequest = [request copy];
        _completionHandler = [completionHandler copy];
        _receivedData = [[NSMutableData alloc] init];
        _state = NSURLSessionTaskStateSuspended;

        @synchronized ([NSURLSessionTask class]) {
            _taskIdentifier = ++lastIdentifier;
        }
    }
    return self;
}

- (void)dealloc
{
    [_originalRequest release];
    [_currentRequest release];
    [_response release];
    [_error release];
    [_receivedData release];
    [_connection release];
    [_taskDescription release];
    [_completionHandler release];
    [super dealloc];
}

- (id)copyWithZone: (NSZone *) zone
{
    // A task is bound to the transfer it started, so handing out a second copy
    // would mean two owners of one request.
    return [self retain];
}

- (NSUInteger)taskIdentifier
{
    return _taskIdentifier;
}

- (NSURLRequest *)originalRequest
{
    return _originalRequest;
}

- (NSURLRequest *)currentRequest
{
    return _currentRequest;
}

- (NSURLResponse *)response
{
    return _response;
}

- (NSError *)error
{
    return _error;
}

- (int64_t)countOfBytesReceived
{
    return _countOfBytesReceived;
}

- (int64_t)countOfBytesSent
{
    return 0;
}

- (int64_t)countOfBytesExpectedToSend
{
    return 0;
}

- (int64_t)countOfBytesExpectedToReceive
{
    return _countOfBytesExpectedToReceive;
}

- (NSURLSessionTaskState)state
{
    return _state;
}

- (NSString *)taskDescription
{
    return _taskDescription;
}

- (void)setTaskDescription: (NSString *) taskDescription
{
    [_taskDescription release];
    _taskDescription = [taskDescription copy];
}

- (void)resume
{
    if (_state != NSURLSessionTaskStateSuspended)
    {
        return;
    }

    _state = NSURLSessionTaskStateRunning;
    // Callers get the task autoreleased, so keep it alive until it finishes.
    [self retain];
    _connection = [[NSURLConnection alloc] initWithRequest:_currentRequest
                                                  delegate:(id<NSURLConnectionDataDelegate>)self
                                          startImmediately:YES];
}

- (void)suspend
{
    if (_state == NSURLSessionTaskStateRunning)
    {
        _state = NSURLSessionTaskStateSuspended;
    }
}

- (void)cancel
{
    if (_state == NSURLSessionTaskStateCompleted)
    {
        return;
    }

    // Only a task that actually started holds the retain taken by -resume.
    BOOL started = _state == NSURLSessionTaskStateRunning;

    [_connection cancel];
    [_connection release];
    _connection = nil;
    _state = NSURLSessionTaskStateCompleted;

    if (started)
    {
        [self autorelease];
    }
}

- (void)finishWithError: (NSError *) error
{
    if (_state == NSURLSessionTaskStateCompleted)
    {
        return;
    }

    [_error release];
    _error = [error retain];
    _state = NSURLSessionTaskStateCompleted;

    void (^handler)(NSData *, NSURLResponse *, NSError *) = _completionHandler;
    if (handler)
    {
        handler(_receivedData, _response, _error);
    }

    [self autorelease];
}

- (void)connection: (NSURLConnection *) connection didReceiveResponse: (NSURLResponse *) response
{
    [_response release];
    _response = [response retain];
    _countOfBytesExpectedToReceive = [response expectedContentLength];
}

- (void)connection: (NSURLConnection *) connection didReceiveData: (NSData *) data
{
    [_receivedData appendData:data];
    _countOfBytesReceived += (int64_t)[data length];
}

- (void)connectionDidFinishLoading: (NSURLConnection *) connection
{
    [self finishWithError:nil];
}

- (void)connection: (NSURLConnection *) connection didFailWithError: (NSError *) error
{
    [self finishWithError:error];
}

@end

@implementation NSURLSessionDataTask
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
