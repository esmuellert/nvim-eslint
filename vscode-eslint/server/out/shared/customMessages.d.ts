import { NotificationType, NotificationType0, RequestType, TextDocumentIdentifier } from 'vscode-languageserver-protocol';
export declare enum Status {
    ok = 1,
    warn = 2,
    error = 3
}
export type StatusParams = {
    uri: string;
    state: Status;
    validationTime?: number;
};
/**
 * The status notification is sent from the server to the client to
 * inform the client about server status changes.
 */
export declare namespace StatusNotification {
    const method: 'eslint/status';
    const type: NotificationType<StatusParams>;
}
export type NoConfigParams = {
    message: string;
    document: TextDocumentIdentifier;
};
export type NoConfigResult = {};
/**
 * The NoConfigRequest is sent from the server to the client to inform
 * the client that no eslint configuration file could be found when
 * trying to lint a file.
 */
export declare namespace NoConfigRequest {
    const method: 'eslint/noConfig';
    const type: RequestType<NoConfigParams, NoConfigResult, void>;
}
export type NoESLintLibraryParams = {
    source: TextDocumentIdentifier;
};
export type NoESLintLibraryResult = {};
/**
 * The NoESLintLibraryRequest is sent from the server to the client to
 * inform the client that no eslint library could be found when trying
 * to lint a file.
 */
export declare namespace NoESLintLibraryRequest {
    const method: 'eslint/noLibrary';
    const type: RequestType<NoESLintLibraryParams, NoESLintLibraryResult, void>;
}
export type OpenESLintDocParams = {
    url: string;
};
export type OpenESLintDocResult = {};
/**
 * The eslint/openDoc request is sent from the server to the client to
 * ask the client to open the documentation URI for a given
 * ESLint rule.
 */
export declare namespace OpenESLintDocRequest {
    const method: 'eslint/openDoc';
    const type: RequestType<OpenESLintDocParams, OpenESLintDocResult, void>;
}
export type ProbeFailedParams = {
    textDocument: TextDocumentIdentifier;
};
/**
 * The eslint/probeFailed request is sent from the server to the client
 * to tell the client the the lint probing for a certain document has
 * failed and that there is no need to sync that document to the server
 * anymore.
 */
export declare namespace ProbeFailedRequest {
    const method: 'eslint/probeFailed';
    const type: RequestType<ProbeFailedParams, void, void>;
}
/**
 * The eslint/showOutputChannel notification is sent from the server to
 * the client to ask the client to reveal it's output channel.
 */
export declare namespace ShowOutputChannel {
    const method: 'eslint/showOutputChannel';
    const type: NotificationType0;
}
/**
 * The eslint/exitCalled notification is sent from the server to the client
 * to inform the client that a process.exit call on the server got intercepted.
 * The call was very likely made by an ESLint plugin.
 */
export declare namespace ExitCalled {
    const method: 'eslint/exitCalled';
    const type: NotificationType<[number, string]>;
}
