# CC01 Frontend タスクキュー

## 優先度: 最高

### 1. TypeScript完全対応
```bash
# 全ファイルのstrictチェック
find src -name "*.tsx" -o -name "*.ts" | while read file; do
    echo "Checking: $file"
    npx tsc --strict --noEmit "$file" 2>&1 | grep -v "node_modules"
done
```

### 2. コンポーネントライブラリの完成
```typescript
// src/components/ui/index.ts
// 全コンポーネントの統合エクスポート
export { Button, ButtonProps } from './Button';
export { Input, InputProps } from './Input';
export { Select, SelectProps } from './Select';
export { Modal, ModalProps } from './Modal';
export { Dialog, DialogProps } from './Dialog';
export { Alert, AlertProps, AlertType } from './Alert';
export { Card, CardProps } from './Card';
export { Table, TableProps, TableColumn } from './Table';
export { Form, FormProps, FormField } from './Form';
export { Tabs, TabsProps, TabPanel } from './Tabs';
export { Dropdown, DropdownProps } from './Dropdown';
export { Tooltip, TooltipProps } from './Tooltip';
export { Pagination, PaginationProps } from './Pagination';
export { Badge, BadgeProps } from './Badge';
export { Progress, ProgressProps } from './Progress';
export { Spinner, SpinnerProps } from './Spinner';
export { Toast, ToastProps, useToast } from './Toast';
export { Drawer, DrawerProps } from './Drawer';
export { Accordion, AccordionProps } from './Accordion';
export { Breadcrumb, BreadcrumbProps } from './Breadcrumb';
```

### 3. テーマシステムの実装
```typescript
// src/theme/ThemeProvider.tsx
import React, { createContext, useContext, useState } from 'react';

export interface Theme {
  colors: {
    primary: string;
    secondary: string;
    danger: string;
    warning: string;
    success: string;
    info: string;
    background: string;
    surface: string;
    text: string;
    textSecondary: string;
  };
  spacing: {
    xs: string;
    sm: string;
    md: string;
    lg: string;
    xl: string;
  };
  borderRadius: {
    sm: string;
    md: string;
    lg: string;
    full: string;
  };
  shadows: {
    sm: string;
    md: string;
    lg: string;
  };
}

const ThemeContext = createContext<{
  theme: Theme;
  setTheme: (theme: Theme) => void;
} | null>(null);

export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) throw new Error('useTheme must be used within ThemeProvider');
  return context;
};
```

## 優先度: 高

### 4. パフォーマンス最適化
```typescript
// src/utils/performance.ts
import { lazy, Suspense, ComponentType } from 'react';

export function lazyWithPreload<T extends ComponentType<any>>(
  factory: () => Promise<{ default: T }>
) {
  const Component = lazy(factory);
  (Component as any).preload = factory;
  return Component;
}

// 使用例
const Dashboard = lazyWithPreload(() => import('./pages/Dashboard'));
// プリロード
Dashboard.preload();
```

### 5. アクセシビリティ対応
```typescript
// src/hooks/useAccessibility.ts
export function useAccessibility() {
  const [screenReaderActive, setScreenReaderActive] = useState(false);
  const [keyboardNavActive, setKeyboardNavActive] = useState(false);
  
  useEffect(() => {
    // スクリーンリーダー検出
    const detectScreenReader = () => {
      const isActive = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      setScreenReaderActive(isActive);
    };
    
    // キーボードナビゲーション検出
    const handleFirstTab = (e: KeyboardEvent) => {
      if (e.key === 'Tab') {
        setKeyboardNavActive(true);
      }
    };
    
    window.addEventListener('keydown', handleFirstTab);
    detectScreenReader();
    
    return () => window.removeEventListener('keydown', handleFirstTab);
  }, []);
  
  return { screenReaderActive, keyboardNavActive };
}
```

### 6. 国際化対応
```typescript
// src/i18n/setup.ts
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

const resources = {
  en: {
    translation: {
      welcome: 'Welcome',
      login: 'Login',
      logout: 'Logout',
      // ... 他の翻訳
    }
  },
  ja: {
    translation: {
      welcome: 'ようこそ',
      login: 'ログイン',
      logout: 'ログアウト',
      // ... 他の翻訳
    }
  }
};

i18n
  .use(initReactI18next)
  .init({
    resources,
    lng: 'en',
    interpolation: {
      escapeValue: false
    }
  });
```

### 7. フォームバリデーション強化
```typescript
// src/utils/validation.ts
import * as yup from 'yup';

export const userSchema = yup.object({
  email: yup.string().email('Invalid email').required('Email is required'),
  firstName: yup.string().min(2).max(50).required('First name is required'),
  lastName: yup.string().min(2).max(50).required('Last name is required'),
  password: yup.string()
    .min(8, 'Password must be at least 8 characters')
    .matches(/[A-Z]/, 'Must contain uppercase letter')
    .matches(/[a-z]/, 'Must contain lowercase letter')
    .matches(/[0-9]/, 'Must contain number')
    .required('Password is required'),
});

export const loginSchema = yup.object({
  email: yup.string().email().required(),
  password: yup.string().required(),
});
```

## 優先度: 中

### 8. Storybook完全対応
```typescript
// .storybook/preview.tsx
import type { Preview } from '@storybook/react';
import { ThemeProvider } from '../src/theme/ThemeProvider';
import '../src/index.css';

const preview: Preview = {
  parameters: {
    actions: { argTypesRegex: '^on[A-Z].*' },
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/,
      },
    },
  },
  decorators: [
    (Story) => (
      <ThemeProvider>
        <Story />
      </ThemeProvider>
    ),
  ],
};
```

### 9. E2Eテスト実装
```typescript
// e2e/login.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Login Flow', () => {
  test('successful login', async ({ page }) => {
    await page.goto('/login');
    
    await page.fill('[data-testid="email-input"]', 'test@example.com');
    await page.fill('[data-testid="password-input"]', 'password123');
    await page.click('[data-testid="login-button"]');
    
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('[data-testid="welcome-message"]')).toContainText('Welcome');
  });
  
  test('failed login shows error', async ({ page }) => {
    await page.goto('/login');
    
    await page.fill('[data-testid="email-input"]', 'wrong@example.com');
    await page.fill('[data-testid="password-input"]', 'wrongpass');
    await page.click('[data-testid="login-button"]');
    
    await expect(page.locator('[data-testid="error-message"]')).toBeVisible();
  });
});
```

### 10. PWA対応
```json
// public/manifest.json
{
  "short_name": "ITDO ERP",
  "name": "ITDO ERP System",
  "icons": [
    {
      "src": "favicon.ico",
      "sizes": "64x64 32x32 24x24 16x16",
      "type": "image/x-icon"
    },
    {
      "src": "logo192.png",
      "type": "image/png",
      "sizes": "192x192"
    },
    {
      "src": "logo512.png",
      "type": "image/png",
      "sizes": "512x512"
    }
  ],
  "start_url": ".",
  "display": "standalone",
  "theme_color": "#000000",
  "background_color": "#ffffff"
}
```

### 11. エラーバウンダリ実装
```typescript
// src/components/ErrorBoundary.tsx
import React, { Component, ErrorInfo, ReactNode } from 'react';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false,
    error: null,
  };

  public static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('Uncaught error:', error, errorInfo);
    // エラーログ送信
    if (process.env.NODE_ENV === 'production') {
      // sendErrorToLoggingService(error, errorInfo);
    }
  }

  public render() {
    if (this.state.hasError) {
      return this.props.fallback || <h1>Something went wrong.</h1>;
    }

    return this.props.children;
  }
}
```

### 12. デバッグツール実装
```typescript
// src/utils/debug.ts
export const Debug = {
  log: (...args: any[]) => {
    if (process.env.NODE_ENV === 'development') {
      console.log('[DEBUG]', ...args);
    }
  },
  
  error: (...args: any[]) => {
    if (process.env.NODE_ENV === 'development') {
      console.error('[ERROR]', ...args);
    }
  },
  
  time: (label: string) => {
    if (process.env.NODE_ENV === 'development') {
      console.time(label);
    }
  },
  
  timeEnd: (label: string) => {
    if (process.env.NODE_ENV === 'development') {
      console.timeEnd(label);
    }
  },
  
  performance: (componentName: string) => {
    return (target: any, propertyKey: string, descriptor: PropertyDescriptor) => {
      const originalMethod = descriptor.value;
      
      descriptor.value = function (...args: any[]) {
        Debug.time(`${componentName}.${propertyKey}`);
        const result = originalMethod.apply(this, args);
        Debug.timeEnd(`${componentName}.${propertyKey}`);
        return result;
      };
      
      return descriptor;
    };
  }
};
```

## 優先度: 低

### 13. アニメーションライブラリ
```typescript
// src/animations/transitions.ts
import { keyframes } from '@emotion/react';

export const fadeIn = keyframes`
  from { opacity: 0; }
  to { opacity: 1; }
`;

export const slideIn = keyframes`
  from { transform: translateX(-100%); }
  to { transform: translateX(0); }
`;

export const scaleIn = keyframes`
  from { transform: scale(0.9); opacity: 0; }
  to { transform: scale(1); opacity: 1; }
`;

export const transitions = {
  fast: '150ms ease-in-out',
  normal: '300ms ease-in-out',
  slow: '500ms ease-in-out',
};
```

### 14. カスタムフック集
```typescript
// src/hooks/index.ts
export { useDebounce } from './useDebounce';
export { useThrottle } from './useThrottle';
export { useLocalStorage } from './useLocalStorage';
export { useSessionStorage } from './useSessionStorage';
export { useMediaQuery } from './useMediaQuery';
export { useIntersectionObserver } from './useIntersectionObserver';
export { useClickOutside } from './useClickOutside';
export { useKeyPress } from './useKeyPress';
export { usePrevious } from './usePrevious';
export { useToggle } from './useToggle';
export { useCounter } from './useCounter';
export { useHover } from './useHover';
export { useFocus } from './useFocus';
export { useEventListener } from './useEventListener';
export { useAsync } from './useAsync';
```

### 15. ドキュメント生成
```bash
# ドキュメント自動生成
npm install --save-dev typedoc

# typedoc.json
{
  "entryPoints": ["src/index.ts"],
  "out": "docs",
  "excludePrivate": true,
  "excludeProtected": true,
  "excludeExternals": true,
  "readme": "README.md",
  "name": "ITDO ERP Frontend",
  "includeVersion": true,
  "disableSources": false
}
```

## 実行順序
1. TypeScript完全対応（最優先）
2. コンポーネントライブラリ完成
3. テーマシステム実装
4. パフォーマンス最適化
5. アクセシビリティ対応
6-15. 順次実装

各タスクの完了後、次のタスクに自動的に移行してください。