import { URI } from 'vscode-uri';
import { TextDocument } from 'vscode-languageserver-textdocument';
/**
 * Special functions to deal with path conversions in the context of ESLint
 */
/**
 * Normalizes the drive letter to upper case which is the default in Node but not in
 * VS Code.
 */
export declare function normalizeDriveLetter(path: string): string;
/**
 * Check if the path follows this pattern: `\\hostname\sharename`.
 *
 * @see https://msdn.microsoft.com/en-us/library/gg465305.aspx
 * @return A boolean indication if the path is a UNC path, on none-windows
 * always false.
 */
export declare function isUNC(path: string): boolean;
export declare function getFileSystemPath(uri: URI): string;
export declare function normalizePath(path: string): string;
export declare function normalizePath(path: undefined): undefined;
export declare function getUri(documentOrUri: string | TextDocument | URI): URI;
