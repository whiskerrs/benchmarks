import { Observable } from '@nativescript/core';

export type LoadState = 'loading' | 'loaded' | 'error';

/** Sets the visibility strings for a loading/loaded/error screen. */
export function setLoadState(vm: Observable, state: LoadState) {
  vm.set('skeletonVisibility', state === 'loading' ? 'visible' : 'collapsed');
  vm.set('contentVisibility', state === 'loaded' ? 'visible' : 'collapsed');
  vm.set('mainVisibility', state === 'error' ? 'collapsed' : 'visible');
  vm.set('errorVisibility', state === 'error' ? 'visible' : 'collapsed');
}
