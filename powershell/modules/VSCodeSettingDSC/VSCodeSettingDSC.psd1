@{
    RootModule = 'VSCodeSettingDSC.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'f7130979-5a5c-4819-be55-863802e1ab0a'
    Author = 'Gijs Reijn'
    Description = 'DSC Resource for Visual Studio Code Settings'
    PowerShellVersion = '7.2'
    FunctionsToExport = @(
        'Get-VSCodeSettings',
        'New-VSCodeSettingClass'
    )
    DscResourcesToExport = @(
        'VSCodeAccessibilitySetting',
        'VSCodeAddedSetting',
        'VSCodeAnnouncementSetting',
        'VSCodeBashSetting',
        'VSCodeBreadcrumbsSetting',
        'VSCodeChatSetting',
        'VSCodeCodeOutputSetting',
        'VSCodeCodeSourceSetting',
        'VSCodeCommentsSetting',
        'VSCodeCommitSetting',
        'VSCodeCompoundsSetting',
        'VSCodeConfigurationsSetting',
        'VSCodeCssSetting',
        'VSCodeDebugSetting',
        'VSCodeDefaultSetting',
        'VSCodeDiffEditorSetting',
        'VSCodeEditorSetting',
        'VSCodeEmmetSetting',
        'VSCodeExtensionsSetting',
        'VSCodeFishSetting',
        'VSCodeGithubSetting',
        'VSCodeGreenSetting',
        'VSCodeGruntSetting',
        'VSCodeGulpSetting',
        'VSCodeHttpSetting',
        'VSCodeIconSetting',
        'VSCodeImagePreviewSetting',
        'VSCodeInlineChatSetting',
        'VSCodeInteractiveWindowSetting',
        'VSCodeIpynbSetting',
        'VSCodeJakeSetting',
        'VSCodeJsonSetting',
        'VSCodeJsProfileVisualizerSetting',
        'VSCodeKeyboardSetting',
        'VSCodeLaunchSetting',
        'VSCodeLessSetting',
        'VSCodeMarkdownSetting',
        'VSCodeMarkupPreviewSetting',
        'VSCodeMarkupSourceSetting',
        'VSCodeMediaPreviewSetting',
        'VSCodeMergeEditorSetting',
        'VSCodeMicrosoftSetting',
        'VSCodeModifiedSetting',
        'VSCodeNotebookSetting',
        'VSCodeNotebookEditorsSetting',
        'VSCodeNpmSetting',
        'VSCodeOtherSetting',
        'VSCodeOutlineSetting',
        'VSCodeOutputSetting',
        'VSCodePackageSetting',
        'VSCodePathSetting',
        'VSCodePhpSetting',
        'VSCodeProblemsSetting',
        'VSCodePubSetting',
        'VSCodePublishSetting',
        'VSCodePwshSetting',
        'VSCodePwshCodeSetting',
        'VSCodePwshGitSetting',
        'VSCodeRedSetting',
        'VSCodeReferencesSetting',
        'VSCodeRemoteSetting',
        'VSCodeReplSetting',
        'VSCodeScreencastModeSetting',
        'VSCodeScssSetting',
        'VSCodeSearchSetting',
        'VSCodeSecuritySetting',
        'VSCodeSettingsSyncSetting',
        'VSCodeShowCommandGroupsSetting',
        'VSCodeShowCommandsSetting',
        'VSCodeShowKeybindingsSetting',
        'VSCodeShowKeysSetting',
        'VSCodeShowSingleEditorCursorMovesSetting',
        'VSCodeSimpleBrowserSetting',
        'VSCodeSoundSetting',
        'VSCodeStringsSetting',
        'VSCodeSyncSetting',
        'VSCodeTaskSetting',
        'VSCodeTelemetrySetting',
        'VSCodeTerminalEditorSetting',
        'VSCodeTestingSetting',
        'VSCodeTimelineSetting',
        'VSCodeTmuxSetting',
        'VSCodeTsconfigSetting',
        'VSCodeUntitledEditorsSetting',
        'VSCodeUpdateSetting',
        'VSCodeVscodeSetting',
        'VSCodeWindowSetting',
        'VSCodeYellowSetting',
        'VSCodeZenModeSetting',
        'VSCodeZshSetting'
    )
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('DesiredStateConfiguration', 'DSC', 'PowerShell', 'VSCode', 'Settings')
        }

        LicenseUri = 'https://github.com/Gijsreyn/random-tools-gijs/LICENSE'

        # A URL to the main website for this project.
        ProjectUri   = 'https://github.com/Gijsreyn/random-tools-gijs/powershell/modules/VSCodeSettingDSC'

        # A URL to an icon representing this module.
        IconUri = 'https://raw.githubusercontent.com/Gijsreyn/random-tools-gijs/main/.images/vscodesettingdsc.png'
    }
}
