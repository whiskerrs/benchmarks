/// <reference path="./node_modules/@nativescript/types/index.d.ts" />

declare class SBNative extends NSObject {
  static logHomeReady(): void;
  static openInAppBrowser(url: string): void;
}
