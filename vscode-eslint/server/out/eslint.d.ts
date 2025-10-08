import { TextDocument } from 'vscode-languageserver-textdocument';
import { Diagnostic, ProposedFeatures, TextEdit, TextDocuments } from 'vscode-languageserver/node';
import { URI } from 'vscode-uri';
import { Status } from './shared/customMessages';
import { ConfigurationSettings, DirectoryItem, ESLintOptions, RuleCustomization, RuleSeverity } from './shared/settings';
/**
 * ESLint specific settings for a text document.
 */
export type TextDocumentSettings = Omit<ConfigurationSettings, 'workingDirectory'> & {
    silent: boolean;
    workingDirectory: DirectoryItem | undefined;
    library: ESLintModule | undefined;
    resolvedGlobalPackageManagerPath: string | undefined;
};
export declare namespace TextDocumentSettings {
    function hasLibrary(settings: TextDocumentSettings): settings is (TextDocumentSettings & {
        library: ESLintModule;
    });
}
/**
 * A special error thrown by the ESLint library
 */
export interface ESLintError extends Error {
    messageTemplate?: string;
    messageData?: {
        pluginName?: string;
    };
}
export declare namespace ESLintError {
    function isNoConfigFound(error: any): boolean;
}
type ESLintAutoFixEdit = {
    range: [number, number];
    text: string;
};
type ESLintSuggestionResult = {
    desc: string;
    fix: ESLintAutoFixEdit;
};
type ESLintProblem = {
    line: number;
    column: number;
    endLine?: number;
    endColumn?: number;
    severity: number;
    ruleId: string;
    message: string;
    fix?: ESLintAutoFixEdit;
    suggestions?: ESLintSuggestionResult[];
};
type ESLintDocumentReport = {
    filePath: string;
    errorCount: number;
    warningCount: number;
    messages: ESLintProblem[];
    output?: string;
};
type ESLintReport = {
    errorCount: number;
    warningCount: number;
    results: ESLintDocumentReport[];
};
export type CLIOptions = {
    cwd?: string;
    fixTypes?: string[];
    fix?: boolean;
};
export type SeverityConf = 0 | 1 | 2 | 'off' | 'warn' | 'error';
export type RuleConf = SeverityConf | [SeverityConf, ...any[]];
export type ConfigData = {
    rules?: Record<string, RuleConf>;
};
export type ESLintClassOptions = {
    cwd?: string;
    fixTypes?: string[];
    fix?: boolean;
    overrideConfig?: ConfigData;
    overrideConfigFile?: string | null;
};
export type RuleMetaData = {
    docs?: {
        url?: string;
    };
    type?: string;
};
export declare namespace RuleMetaData {
    const unusedDisableDirectiveId = "unused-disable-directive";
    function capture(eslint: ESLintClass, reports: ESLintDocumentReport[]): void;
    function clear(): void;
    function getUrl(ruleId: string): string | undefined;
    function getType(ruleId: string): string | undefined;
    function hasRuleId(ruleId: string): boolean;
    function isUnusedDisableDirectiveProblem(problem: ESLintProblem): boolean;
}
type ParserOptions = {
    parser?: string;
};
type ESLintRcConfig = {
    env: Record<string, boolean>;
    extends: string | string[];
    ignorePatterns: string | string[];
    noInlineConfig: boolean;
    parser: string | null;
    parserOptions?: ParserOptions;
    plugins: string[];
    processor: string;
    reportUnusedDisableDirectives: boolean | undefined;
    root: boolean;
    rules: Record<string, RuleConf>;
    settings: object;
};
type ESLintConfig = ESLintRcConfig;
export type Problem = {
    label: string;
    documentVersion: number;
    ruleId: string;
    line: number;
    diagnostic: Diagnostic;
    edit?: ESLintAutoFixEdit;
    suggestions?: ESLintSuggestionResult[];
};
export declare namespace Problem {
    function isFixable(problem: Problem): problem is FixableProblem;
    function hasSuggestions(problem: Problem): problem is SuggestionsProblem;
}
export type FixableProblem = Problem & {
    edit: ESLintAutoFixEdit;
};
export declare namespace FixableProblem {
    function createTextEdit(document: TextDocument, editInfo: FixableProblem): TextEdit;
}
export type SuggestionsProblem = Problem & {
    suggestions: ESLintSuggestionResult[];
};
export declare namespace SuggestionsProblem {
    function createTextEdit(document: TextDocument, suggestion: ESLintSuggestionResult): TextEdit;
}
interface ESLintClass extends Object {
    lintText(content: string, options: {
        filePath?: string;
        warnIgnored?: boolean;
    }): Promise<ESLintDocumentReport[]>;
    isPathIgnored(path: string): Promise<boolean>;
    getRulesMetaForResults?(results: ESLintDocumentReport[]): Record<string, RuleMetaData> | undefined;
    calculateConfigForFile(path: string): Promise<ESLintConfig | undefined>;
    isCLIEngine?: boolean;
}
declare namespace ESLintClass {
    function getConfigType(eslint: ESLintClass): 'eslintrc' | 'flat';
}
interface ESLintClassConstructor {
    configType?: 'eslintrc' | 'flat';
    version?: string;
    new (options: ESLintClassOptions): ESLintClass;
}
interface CLIEngineConstructor {
    new (options: CLIOptions): CLIEngine;
}
/**
 * A loaded ESLint npm module.
 */
export type ESLintModule = {
    ESLint: undefined;
    CLIEngine: CLIEngineConstructor;
    loadESLint?: undefined;
} | {
    ESLint: ESLintClassConstructor;
    CLIEngine: CLIEngineConstructor;
    loadESLint?: undefined;
} | {
    ESLint: ESLintClassConstructor;
    isFlatConfig?: boolean;
    CLIEngine: undefined;
    loadESLint?: (options?: {
        cwd?: string;
        useFlatConfig?: boolean;
    }) => Promise<ESLintClassConstructor>;
};
export declare namespace ESLintModule {
    function hasLoadESLint(value: ESLintModule): value is {
        ESLint: ESLintClassConstructor;
        CLIEngine: undefined;
        loadESLint: (options?: {
            cwd?: string;
            useFlatConfig?: boolean;
        }) => Promise<ESLintClassConstructor>;
    };
    function hasESLintClass(value: ESLintModule): value is {
        ESLint: ESLintClassConstructor;
        CLIEngine: undefined;
    };
    function hasCLIEngine(value: ESLintModule): value is {
        ESLint: undefined;
        CLIEngine: CLIEngineConstructor;
    };
    function isFlatConfig(value: ESLintModule): value is {
        ESLint: ESLintClassConstructor;
        CLIEngine: undefined;
        isFlatConfig: true;
    };
}
type RuleData = {
    meta?: RuleMetaData;
};
declare namespace RuleData {
    function hasMetaType(value: RuleMetaData | undefined): value is RuleMetaData & {
        type: string;
    };
}
interface CLIEngine {
    executeOnText(content: string, file?: string, warn?: boolean): ESLintReport;
    isPathIgnored(path: string): boolean;
    getRules?(): Map<string, RuleData>;
    getConfigForFile?(path: string): ESLintConfig;
}
declare namespace CLIEngine {
    function hasRule(value: CLIEngine): value is CLIEngine & {
        getRules(): Map<string, RuleData>;
    };
}
/**
 * Class for dealing with Fixes.
 */
export declare class Fixes {
    private edits;
    constructor(edits: Map<string, Problem>);
    static overlaps(a: FixableProblem | undefined, b: FixableProblem): boolean;
    static sameRange(a: FixableProblem, b: FixableProblem): boolean;
    isEmpty(): boolean;
    getDocumentVersion(): number;
    getScoped(diagnostics: Diagnostic[]): Problem[];
    getAllSorted(): FixableProblem[];
    getApplicable(): FixableProblem[];
}
export type SaveRuleConfigItem = {
    offRules: Set<string>;
    onRules: Set<string>;
    options: ESLintOptions | undefined;
};
/**
 * Manages the special save rule configurations done in the VS Code settings.
 */
export declare namespace SaveRuleConfigs {
    let inferFilePath: (documentOrUri: string | TextDocument | URI | undefined) => string | undefined;
    function get(uri: string, settings: TextDocumentSettings & {
        library: ESLintModule;
    }): Promise<SaveRuleConfigItem | undefined>;
    function remove(key: string): boolean;
    function clear(): void;
}
/**
 * Manages rule severity overrides done using VS Code settings.
 */
export declare namespace RuleSeverities {
    function getOverride(ruleId: string, customizations: RuleCustomization[], isFixable?: boolean): RuleSeverity | undefined;
    function clear(): void;
}
/**
 * Capture information necessary to compute code actions.
 */
export declare namespace CodeActions {
    function get(uri: string): Map<string, Problem> | undefined;
    function set(uri: string, value: Map<string, Problem>): void;
    function remove(uri: string): boolean;
    function record(document: TextDocument, diagnostic: Diagnostic, problem: ESLintProblem): void;
}
/**
 * Wrapper round the ESLint npm module.
 */
export declare namespace ESLint {
    function initialize($connection: ProposedFeatures.Connection, $documents: TextDocuments<TextDocument>, $inferFilePath: (documentOrUri: string | TextDocument | URI | undefined) => string | undefined, $loadNodeModule: <T>(moduleName: string) => T | undefined): void;
    function removeSettings(key: string): boolean;
    function clearSettings(): void;
    function unregisterAsFormatter(document: TextDocument): void;
    function clearFormatters(): void;
    function resolveSettings(document: TextDocument): Promise<TextDocumentSettings>;
    function newClass(library: ESLintModule, newOptions: ESLintClassOptions | CLIOptions, settings: TextDocumentSettings): Promise<ESLintClass>;
    function withClass<T>(func: (eslintClass: ESLintClass) => Promise<T>, settings: TextDocumentSettings & {
        library: ESLintModule;
    }, options?: ESLintClassOptions | CLIOptions): Promise<T>;
    function getFilePath(document: TextDocument | undefined, settings: TextDocumentSettings): string | undefined;
    function validate(document: TextDocument, settings: TextDocumentSettings & {
        library: ESLintModule;
    }): Promise<Diagnostic[]>;
    function findWorkingDirectory(workspaceFolder: string, file: string | undefined): [string, boolean];
    namespace ErrorHandlers {
        const single: ((error: any, document: TextDocument, library: ESLintModule, settings: TextDocumentSettings) => Status | undefined)[];
        function getMessage(err: any, document: TextDocument): string;
        function clearNoConfigReported(): void;
        function getConfigErrorReported(key: string): {
            library: ESLintModule;
            settings: TextDocumentSettings;
        } | undefined;
        function removeConfigErrorReported(key: string): boolean;
        function clearMissingModuleReported(): void;
    }
}
export {};
