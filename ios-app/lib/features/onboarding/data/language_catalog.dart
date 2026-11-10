class AppLanguage {
  const AppLanguage(this.name, this.nativeName, this.code, this.flag);

  final String name;
  final String nativeName;
  final String code;
  final String flag;
}

const languageCatalog = <AppLanguage>[
  AppLanguage('English', 'English', 'en', '🇬🇧'),
  AppLanguage('Kiswahili', 'Kiswahili', 'sw', '🇰🇪'),
];
