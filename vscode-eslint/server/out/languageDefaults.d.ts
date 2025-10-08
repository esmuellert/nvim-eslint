declare namespace LanguageDefaults {
    function getLineComment(languageId: string): string;
    function getBlockComment(languageId: string): [string, string];
    function getExtension(languageId: string): string | undefined;
}
export default LanguageDefaults;
