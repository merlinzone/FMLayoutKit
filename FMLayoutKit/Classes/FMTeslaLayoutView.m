//
//  FMTeslaLayoutView.m
//  FMCollectionLayout_Example
//
//  Created by 周发明 on 2020/4/8.
//  Copyright © 2020 周发明. All rights reserved.
//

#import "FMTeslaLayoutView.h"
#import "FMLayoutView.h"
#import "FMTeslaSuspensionHeightChangeDelegate.h"

@interface FM_ScrollView : UIScrollView

@property(nonatomic, copy)BOOL(^panGesCanBegin)(CGPoint panPoint);

@end

@implementation FM_ScrollView

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer{
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint panPoint = [pan locationInView:self];
        if (self.panGesCanBegin) {
            return self.panGesCanBegin(panPoint);
        }
    }
    return [super gestureRecognizerShouldBegin:gestureRecognizer];
}

@end

@interface FMTeslaLayoutView ()<FMCollectionLayoutViewConfigurationDelegate, UICollectionViewDelegate, UIGestureRecognizerDelegate>

@property(nonatomic, weak)FMLayoutBaseSection *suspensionAlwaysHeader;
@property(nonatomic, weak)FM_ScrollView *scrollView;

@property(nonatomic, strong)FMLayoutView *shareLayoutView;
@property(nonatomic, weak)FMLayoutView *currentLayoutView;

@property(nonatomic, strong)NSMutableDictionary<NSNumber *, FMLayoutView *> *layoutViews;

@property(nonatomic, assign)BOOL isLayoutSubView;
@property(nonatomic, assign)BOOL isLoadSubView;


@property(nonatomic, assign)CGFloat shareHeight;
@property(nonatomic, assign, readonly)CGFloat shareSuspensionDifferHeight;

@end

@implementation FMTeslaLayoutView

- (void)reLoadSubViews{
    if (self.isLayoutSubView && self.isLoadSubView) {
        self.isLoadSubView = NO;
        for (UIView *view in self.layoutViews) {
            [view removeFromSuperview];
        }
        [self loadSubViews];
    }
}

- (void)reloadData{
    [self.shareLayoutView reloadData];
    [self.currentLayoutView reloadData];
}

- (void)reloadDataWithIndex:(NSInteger)index{
    FMLayoutView *layoutView = self.layoutViews[@(index)];
    if (layoutView) {
        [layoutView reloadData];
    }
}

- (void)scrollToIndex:(NSInteger)index animated:(BOOL)animated{
    CGFloat offsetX = index * self.scrollView.bounds.size.width;
    if (offsetX == self.scrollView.contentOffset.x) {
        return;
    }
    if (animated) {
        self.userInteractionEnabled = NO;
    }
    [self scrollStart];
    [self.scrollView setContentOffset:CGPointMake(offsetX, 0) animated:animated];
    if (!animated) {
        [self scrollEnd];
    }
}

- (void)dealloc{
    FMLayoutLog(@"FMTeslaLayoutView  dealloc");
    [self.currentLayoutView removeObserver:self forKeyPath:@"contentOffset"];
}

- (CGFloat)shareSuspensionDifferHeight{
    if (self.suspensionAlwaysHeader) {
        if ([self.delegate respondsToSelector:@selector(shareSuspensionMinHeightWithTesla:)]) {
            CGFloat min = [self.delegate shareSuspensionMinHeightWithTesla:self];
            if (self.suspensionAlwaysHeader.header.size > min) {
                return self.suspensionAlwaysHeader.header.size - min;
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    }
    return 0;
}

- (FM_ScrollView *)scrollView{
    if (_scrollView == nil) {
        FM_ScrollView *scroll = [[FM_ScrollView alloc] init];
        scroll.backgroundColor = [UIColor clearColor];
        scroll.pagingEnabled = YES;
        scroll.delegate = self;
        scroll.bounces = YES;
        scroll.alwaysBounceHorizontal = YES;
        scroll.showsHorizontalScrollIndicator = NO;
        [self addSubview:scroll];
        __weak typeof(self) weakSelf = self;
        [scroll setPanGesCanBegin:^BOOL(CGPoint panPoint) {
            CGFloat offsetY = weakSelf.currentLayoutView.contentOffset.y;
            CGFloat topCanPanY = weakSelf.shareLayoutView.frame.size.height + weakSelf.shareLayoutView.frame.origin.y - offsetY;
            if (topCanPanY < weakSelf.suspensionAlwaysHeader.header.size) {
                topCanPanY = weakSelf.suspensionAlwaysHeader.header.size;
            }
            return panPoint.y > topCanPanY;
        }];
        _scrollView = scroll;
    }
    return _scrollView;
}

- (FMLayoutView *)shareLayoutView{
    if (_shareLayoutView == nil) {
        _shareLayoutView = [[FMLayoutView alloc] init];
        _shareLayoutView.backgroundColor = [UIColor clearColor];
    }
    return _shareLayoutView;
}

- (void)setCurrentLayoutView:(FMLayoutView *)currentLayoutView{
    if (_currentLayoutView) {
        [_currentLayoutView removeObserver:self forKeyPath:@"contentOffset"];
    }
    _currentLayoutView = currentLayoutView;
    if (currentLayoutView) {
        [currentLayoutView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
    }
}

- (void)setHorizontalCanScroll:(BOOL)horizontalCanScroll{
    _horizontalCanScroll = horizontalCanScroll;
    self.scrollView.scrollEnabled = horizontalCanScroll;
}

- (void)setClipsToBounds:(BOOL)clipsToBounds{
    self.scrollView.clipsToBounds = clipsToBounds;
    self.shareLayoutView.clipsToBounds = clipsToBounds;
    [self.layoutViews.allValues enumerateObjectsUsingBlock:^(FMLayoutView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.clipsToBounds = clipsToBounds;
    }];
    [super setClipsToBounds:clipsToBounds];
}

- (void)setUserInteractionEnabled:(BOOL)userInteractionEnabled{
    if (!userInteractionEnabled) {
        
    }
    [super setUserInteractionEnabled:userInteractionEnabled];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.clipsToBounds = YES;
        self.horizontalCanScroll = YES;
        self.layoutViews = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)loadSubViews{
    [self.layoutViews.allValues enumerateObjectsUsingBlock:^(FMLayoutView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj removeFromSuperview];
    }];
    [self.layoutViews removeAllObjects];
    CGFloat shareHeight = 0;
    if ([self.dataSource respondsToSelector:@selector(shareSectionsInTesla:)]) {
        NSMutableArray<FMLayoutBaseSection *> *sections = [[self.dataSource shareSectionsInTesla:self] mutableCopy];
        if (self.shareLayoutView.superview != self) {
            [self.shareLayoutView removeFromSuperview];
            [self addSubview:self.shareLayoutView];
            self.shareLayoutView.frame = self.bounds;
        }
        [self.shareLayoutView.layout setSections:sections];
        [self.shareLayoutView reloadData];
        [self.shareLayoutView layoutIfNeeded];
        shareHeight = [self.shareLayoutView.layout collectionViewContentSize].height;
        self.shareLayoutView.frame = CGRectMake(0, 0, self.bounds.size.width, shareHeight);
        self.suspensionAlwaysHeader = sections.count > 0 ? ([sections lastObject].header.type == FMLayoutHeaderTypeSuspensionAlways ? [sections lastObject] :nil) : nil;
    } else {
        self.shareLayoutView.frame = CGRectZero;
    }
    self.shareHeight = shareHeight;
    
    NSInteger nums = [self.dataSource numberOfScreenInTesla:self];
    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width * nums, 0);
    [self setCurrentLayoutViewWithIndex:self.selectIndex];
    [self.shareLayoutView removeFromSuperview];
    [self.currentLayoutView addSubview:self.shareLayoutView];
    [self.shareLayoutView reloadData];
    self.isLoadSubView = YES;
    [self scrollToIndex:self.selectIndex animated:NO];
}

- (void)setCurrentLayoutViewWithIndex:(NSInteger)index{
    FMLayoutView *layoutView = self.layoutViews[@(index)];
    if (layoutView == nil) {
        
        if ([self.delegate respondsToSelector:@selector(tesla:willCreateLayoutViewWithIndex:)]) {
            [self.delegate tesla:self willCreateLayoutViewWithIndex:index];
        }
        
        FMLayoutView *collectionView;
        
        if ([self.delegate respondsToSelector:@selector(tesla:customCreateWithIndex:)]) {
            collectionView = [self.delegate tesla:self customCreateWithIndex:index];
        } else {
            collectionView = [[FMLayoutView alloc] initWithFrame:CGRectMake(self.scrollView.bounds.size.width * index, 0, self.scrollView.bounds.size.width, self.scrollView.bounds.size.height)];
            collectionView.backgroundColor = [UIColor clearColor];
            collectionView.bounces = YES;
            collectionView.alwaysBounceVertical = YES;
            collectionView.showsVerticalScrollIndicator = NO;
            collectionView.clipsToBounds = self.clipsToBounds;
            collectionView.layout.minContentSize = self.shareHeight - self.suspensionAlwaysHeader.header.size + self.scrollView.bounds.size.height;
            [collectionView.layout setFirstSectionOffset:self.shareHeight];
            [collectionView.layout setSections:[self.dataSource tesla:self sectionsInScreenIndex:index]];
        }
        
        if ([self.delegate respondsToSelector:@selector(tesla:didCreatedLayoutViewWithIndex:layoutView:)]) {
            [self.delegate tesla:self didCreatedLayoutViewWithIndex:index layoutView:collectionView];
        }
        
        [self.scrollView addSubview:collectionView];
        
        [collectionView reloadData];
        self.layoutViews[@(index)] = collectionView;
        layoutView = collectionView;
        
        if (self.currentLayoutView) {
            CGPoint contentOffset = self.currentLayoutView.contentOffset;
            if (contentOffset.y < self.shareLayoutView.frame.size.height-self.suspensionAlwaysHeader.sectionSize+self.shareSuspensionDifferHeight) {
                collectionView.contentOffset = contentOffset;
            } else {
                collectionView.contentOffset = CGPointMake(contentOffset.x, self.shareLayoutView.frame.size.height-self.suspensionAlwaysHeader.sectionSize+self.shareSuspensionDifferHeight);
            }
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(tesla:currentShowLayoutView:index:)]) {
        [self.delegate tesla:self currentShowLayoutView:layoutView index:index];
    }
    
    self.currentLayoutView = layoutView;
}

- (void)layoutSubviews{
    [super layoutSubviews];
    self.scrollView.frame = self.bounds;
    self.isLayoutSubView = YES;
    if (!self.isLoadSubView) {
        [self loadSubViews];
    }
}

- (void)scrollStart{
    if (!self.scrollView.tracking) {
        self.userInteractionEnabled = NO;
    }
    if (self.shareLayoutView.superview != self) {
        [self.shareLayoutView removeFromSuperview];
    }
    CGRect frame = self.shareLayoutView.frame;
    frame.origin.y =  - self.currentLayoutView.contentOffset.y;
    CGFloat minY = self.suspensionAlwaysHeader.sectionSize - self.shareLayoutView.frame.size.height - self.shareSuspensionDifferHeight;
    if (frame.origin.y < minY) {
        frame.origin.y = minY;
    }
    self.shareLayoutView.frame = frame;
    [self addSubview:self.shareLayoutView];
}

- (void)scrollEnd{
    self.userInteractionEnabled = YES;
    NSInteger index = self.scrollView.contentOffset.x / self.scrollView.bounds.size.width;
    
    [self setCurrentLayoutViewWithIndex:index];
    
    if (self.shareLayoutView.superview != self.currentLayoutView) {
        [self.shareLayoutView removeFromSuperview];
    }
    
    if ([self.delegate respondsToSelector:@selector(tesla:didScrollEnd:currentLayoutView:)]) {
        [self.delegate tesla:self didScrollEnd:index currentLayoutView:self.currentLayoutView];
    }
    
    CGFloat y = self.currentLayoutView.contentOffset.y;
    if (y < self.shareLayoutView.frame.size.height-self.suspensionAlwaysHeader.sectionSize+self.shareSuspensionDifferHeight) {
        CGRect frame = self.shareLayoutView.frame;
        frame.origin.y = 0;
        frame.origin.x = 0;
        self.shareLayoutView.frame = frame;
    } else {
        CGRect frame = self.shareLayoutView.frame;
        frame.origin.y = y + self.suspensionAlwaysHeader.sectionSize - self.shareSuspensionDifferHeight - self.shareLayoutView.frame.size.height;
        frame.origin.x = 0;
        self.shareLayoutView.frame = frame;
    }
    [self.currentLayoutView addSubview:self.shareLayoutView];
    self.selectIndex = index;
}

#pragma mark -------  observeValueForKeyPath
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    CGPoint contentOffset = [change[NSKeyValueChangeNewKey] CGPointValue];
    if ([self.delegate respondsToSelector:@selector(tesla:currentLayoutViewScrollDidScroll:contentOffset:)]) {
        [self.delegate tesla:self currentLayoutViewScrollDidScroll:self.currentLayoutView contentOffset:contentOffset];
    }
    if (contentOffset.y < self.shareLayoutView.frame.size.height-self.suspensionAlwaysHeader.sectionSize+self.shareSuspensionDifferHeight) {
        for (FMLayoutView *coll in self.layoutViews.allValues) {
            if (coll != self.currentLayoutView) {
                coll.contentOffset = contentOffset;
            } else {
                CGRect frame = self.shareLayoutView.frame;
                frame.origin.y = 0;
                frame.size.height = self.shareHeight;
                self.shareLayoutView.frame = frame;
                
                if (contentOffset.y < 0) {
                    CGRect frame = self.shareLayoutView.frame;
                    frame.origin.y = contentOffset.y;
                    frame.size.height = self.shareHeight - contentOffset.y;
                    self.shareLayoutView.frame = frame;
                    if (!self.allShareStickTop) {
                        self.shareLayoutView.contentOffset = CGPointMake(0, contentOffset.y);
                    }
                }
                
                if (contentOffset.y > self.shareLayoutView.frame.size.height-self.suspensionAlwaysHeader.sectionSize) {
                    
                    if (@available(iOS 9.0, *)) {
                        UICollectionReusableView *header = [self.shareLayoutView supplementaryViewForElementKind:self.suspensionAlwaysHeader.header.elementKind atIndexPath:self.suspensionAlwaysHeader.indexPath];
                        CGFloat diff = (contentOffset.y - self.shareLayoutView.frame.size.height+self.suspensionAlwaysHeader.sectionSize);
                        CGFloat showHeight = self.suspensionAlwaysHeader.header.size - diff;
                        if ([header conformsToProtocol:@protocol(FMTeslaSuspensionHeightChangeDelegate)] && [header respondsToSelector:@selector(teslaSuspensionHeaderShouldShowHeight:)]) {
                            [header performSelector:@selector(teslaSuspensionHeaderShouldShowHeight:) withObject:@(showHeight)];
                        }
                    } else {
                        // Fallback on earlier versions
                    }
                } else {
                    if (@available(iOS 9.0, *)) {
                        UICollectionReusableView *header = [self.shareLayoutView supplementaryViewForElementKind:self.suspensionAlwaysHeader.header.elementKind atIndexPath:self.suspensionAlwaysHeader.indexPath];
                        CGFloat diff = 0;
                        CGFloat showHeight = self.suspensionAlwaysHeader.header.size - diff;
                        if ([header conformsToProtocol:@protocol(FMTeslaSuspensionHeightChangeDelegate)] && [header respondsToSelector:@selector(teslaSuspensionHeaderShouldShowHeight:)]) {
                            [header performSelector:@selector(teslaSuspensionHeaderShouldShowHeight:) withObject:@(showHeight)];
                        }
                    } else {
                        // Fallback on earlier versions
                    }
                }
            }
        }
    } else {
        for (FMLayoutView *coll in self.layoutViews.allValues) {
            if (coll != self.currentLayoutView) {
                if (coll.contentOffset.y < self.shareLayoutView.frame.size.height-self.suspensionAlwaysHeader.sectionSize + self.shareSuspensionDifferHeight) {
                    coll.contentOffset = CGPointMake(0, self.shareLayoutView.frame.size.height-self.suspensionAlwaysHeader.sectionSize + self.shareSuspensionDifferHeight);
                }
            } else {
                CGRect frame = self.shareLayoutView.frame;
                frame.origin.y = contentOffset.y - self.shareLayoutView.frame.size.height+self.suspensionAlwaysHeader.sectionSize-self.shareSuspensionDifferHeight;
                frame.size.height = self.shareHeight;
                self.shareLayoutView.frame = frame;
                
                if (@available(iOS 9.0, *)) {
                    UICollectionReusableView *header = [self.shareLayoutView supplementaryViewForElementKind:self.suspensionAlwaysHeader.header.elementKind atIndexPath:self.suspensionAlwaysHeader.indexPath];
                    CGFloat diff = self.shareSuspensionDifferHeight;
                    CGFloat showHeight = self.suspensionAlwaysHeader.header.size - diff;
                    if ([header conformsToProtocol:@protocol(FMTeslaSuspensionHeightChangeDelegate)] && [header respondsToSelector:@selector(teslaSuspensionHeaderShouldShowHeight:)]) {
                        [header performSelector:@selector(teslaSuspensionHeaderShouldShowHeight:) withObject:@(showHeight)];
                    }
                } else {
                   
                }
            }
        }
    }
}

#pragma mark -------  scrollView  delegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    if (scrollView == self.scrollView) {
        if ([self.delegate respondsToSelector:@selector(tesla:scrollViewDidScroll:)]) {
            [self.delegate tesla:self scrollViewDidScroll:scrollView];
        }
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    if (scrollView == self.scrollView) {
        [self scrollStart];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    if (scrollView == self.scrollView) {
        [self scrollEnd];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
    if (scrollView == self.scrollView) {
        if (!decelerate) {
            [self scrollEnd];
        } else {
            self.userInteractionEnabled = NO;
        }
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView{
    if (scrollView == self.scrollView) {
        [self scrollEnd];
    }
}

@end
