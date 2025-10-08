import { WorkspaceFolder } from 'vscode-languageserver-protocol';
export declare enum Validate {
    on = "on",
    off = "off",
    probe = "probe"
}
export type CodeActionSettings = {
    disableRuleComment: {
        enable: boolean;
        location: 'separateLine' | 'sameLine';
        commentStyle: 'line' | 'block';
    };
    showDocumentation: {
        enable: boolean;
    };
};
export declare enum CodeActionsOnSaveMode {
    all = "all",
    problems = "problems"
}
export declare namespace CodeActionsOnSaveMode {
    function from(value: string | undefined | null): CodeActionsOnSaveMode;
}
export declare namespace CodeActionsOnSaveRules {
    function from(value: string[] | undefined | null): string[] | undefined;
}
export declare namespace CodeActionsOnSaveOptions {
    function from(value: object | undefined | null): ESLintOptions | undefined;
}
export type CodeActionsOnSaveSettings = {
    mode: CodeActionsOnSaveMode;
    rules?: string[];
    options?: ESLintOptions;
};
export declare enum ESLintSeverity {
    off = "off",
    warn = "warn",
    error = "error"
}
export declare namespace ESLintSeverity {
    function from(value: string | undefined | null): ESLintSeverity;
}
export declare enum RuleSeverity {
    info = "info",
    warn = "warn",
    error = "error",
    off = "off",
    default = "default",
    downgrade = "downgrade",
    upgrade = "upgrade"
}
export type RuleCustomization = {
    rule: string;
    severity: RuleSeverity;
    /** Only apply to autofixable rules */
    fixable?: boolean;
};
export type RunValues = 'onType' | 'onSave';
export declare enum ModeEnum {
    auto = "auto",
    location = "location"
}
export declare namespace ModeEnum {
    function is(value: string): value is ModeEnum;
}
export type ModeItem = {
    mode: ModeEnum;
};
export declare namespace ModeItem {
    function is(item: any): item is ModeItem;
}
export type DirectoryItem = {
    directory: string;
    '!cwd'?: boolean;
};
export declare namespace DirectoryItem {
    function is(item: any): item is DirectoryItem;
}
export type PackageManagers = 'npm' | 'yarn' | 'pnpm';
export type ESLintOptions = object & {
    fixTypes?: string[];
};
export type ConfigurationSettings = {
    validate: Validate;
    packageManager: PackageManagers;
    useESLintClass: boolean;
    useFlatConfig?: boolean | undefined;
    experimental?: {
        useFlatConfig: boolean;
    };
    codeAction: CodeActionSettings;
    codeActionOnSave: CodeActionsOnSaveSettings;
    format: boolean;
    quiet: boolean;
    onIgnoredFiles: ESLintSeverity;
    options: ESLintOptions | undefined;
    rulesCustomizations: RuleCustomization[];
    run: RunValues;
    problems: {
        shortenToSingleLine: boolean;
    };
    nodePath: string | null;
    workspaceFolder: WorkspaceFolder | undefined;
    workingDirectory: ModeItem | DirectoryItem | undefined;
};
